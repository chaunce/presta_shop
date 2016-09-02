module PrestaShop
  class Resource < OpenStruct
    attr_reader :schema_synopsis, :xml

    def initialize(*args)
      super
      cast_attribute_data_types_from_schema_synopsis if self.schema_synopsis.present?
    end

    def schema_synopsis=(schema)
      @schema_synopsis = schema
      cast_attribute_data_types_from_schema_synopsis      
    end

    def xml=(xml)
      @xml = xml
    end

    private

    def cast_attribute_data_types_from_schema_synopsis
      self.marshal_dump.keys.each { |attribute| cast_attribute_from_schema(attribute) }
    end

    def cast_attribute_from_schema(attribute, nested = [])
      nested_attribute = nested + [attribute]
      format = case attribute
      when :id then 'isUnsignedId'
      else
        nested_schema_synopsis = @schema_synopsis.dig(*nested_attribute.reject{ |v| v.is_a? Integer })
        nested_schema_synopsis.try(:format) if nested_schema_synopsis.is_a? OpenStruct
      end

      nested_attribute_data = self.dig(*nested_attribute)
      if nested_attribute_data.class == self.class
        nested_attribute_data.marshal_dump.keys.each { |attribute| cast_attribute_from_schema(attribute, nested_attribute) }
      elsif nested_attribute_data.class == Array && ( nested_attribute_data.none? && nested_attribute_data.first.class == self.class )
        nested_attribute_data.each_with_index do |_, i|
          array_nested_attribute = nested_attribute + [i]
          self.dig(*array_nested_attribute).marshal_dump.keys.each { |attribute| cast_attribute_from_schema(attribute, array_nested_attribute) }
        end
      elsif nested_attribute_data.class == Array
        # resource = PrestaShop::API.normalize_resource(self.class.name.demodulize.underscore)
        # xpath = PrestaShop::API::XPATH_MAP.dig(resource, :find) || resource.to_s.singularize

        # builds an array of nested objects
        # could be better, but will work for now
        segment = nested.any? ? self.dig(*nested) : self
        segment[attribute] = xml.xpath(nested_attribute.join('/')).collect do |element|
          self.class.new(element.collect.to_h.merge({nested.last || :name => Hash.from_xml(element.to_s).values.first}))
        end
      else
        segment = nested.any? ? self.dig(*nested) : self
        segment[attribute] = cast_value_from_schema_format(segment[attribute], format)
      end
    end

    def cast_value_from_schema_format(value, schema_format)
      case schema_format
      when 'isBool'
        case value
        when '1' then true
        else false
        end
      when 'isFloat', 'isPrice', 'isUnsignedFloat'
        (value.to_f * 100).round / 100.0
      when 'isNegativePrice'
        formated_value = (value.to_f * 100).round / 100.0
        formated_value.zero? ? formated_value : formated_value * -1
      when 'isInt', 'isNullOrUnsignedId', 'isUnsignedId', 'isImageSize', 'isUnsignedInt'
        case value
        when nil, /null/i then nil
        when /\D/ then value
        else value.to_i
        end
      when 'isSerializedArray'
        value.to_s.split(';')
      when 'isBirthDate', 'isDateFormat', 'isDate'
        case value
        when '0000-00-00', '0000-00-00 00:00:00', nil then nil
        when /^\d{4}-\d{2}-\d{2}$/ then value.to_date
        when /^\d{4}-\d{2}-\d{2} \d/ then value.to_datetime
        else value.to_date
        end
      when 'isPercentage'
        "#{value}%"
      else
        value
      end
    end

  end
end

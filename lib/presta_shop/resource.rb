module PrestaShop
  class Resource < OpenStruct
    attr_reader :schema_synopsis

    def initialize
      super
      cast_attribute_data_types_from_schema_synopsis if self.schema_synopsis.present?
    end

    def schema_synopsis=(schema)
      @schema_synopsis = schema
      cast_attribute_data_types_from_schema_synopsis      
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

      if self.dig(*nested_attribute).class == self.class
        self.dig(*nested_attribute).marshal_dump.keys.each { |attribute| cast_attribute_from_schema(attribute, nested_attribute) }
      elsif self.dig(*nested_attribute).class == Array
        self.dig(*nested_attribute).each_with_index do |_, i|
          array_nested_attribute = nested_attribute + [i]
          self.dig(*array_nested_attribute).marshal_dump.keys.each { |attribute| cast_attribute_from_schema(attribute, array_nested_attribute) }
        end
      else
        puts [self.class, self.id].inspect if value == '1' && format == 'isBool'
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

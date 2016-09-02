module PrestaShop

  # Each instance represents a Prestashop API instance.
  class API
    XPATH_MAP = {
      content_management_system: {
        find: :content,
        list: :content_management_system
      },
      product_customization_fields: {
        find: :customization_field,
        list: :customization_fields
      },
      stock_movements: {
        find: :stock_mvt,
        list: :stock_mvts
      },
      order_discounts: {
        find: :order_cart_rule,
        list: :order_cart_rules
      },
    }

    # @return [String] URI of the Prestashop API
    attr_reader :api_uri

    # @return [String] API key
    attr_reader :key
    attr_reader :client

    class << self
      def normalize_resource(resource)
        resource = resource.to_s.pluralize.to_sym
        resource = resource.to_s.singularize.to_sym if [:order_slips, :content_management_systems].include?(resource)
        resource
      end
    end

    # Create a new instance
    # @param url [String] base URL of the Prestashop installation. Do not append "/api" to it, the gem does it internally.
    #   E.g. use "http://my.prestashop.com", not "http://my.prestashop.com/api"
    # @param key [String] a valid API key
    def initialize(url, key)
      @api_uri = UriHandler.api_uri url
      @key = key
      @client = RestClient::Resource.new api_uri, user: key, password: ''
    end

    # List resources that the API key can access
    # @return [Array<Symbol>] list of resources the API can access
    def resources
      @resources ||= Nokogiri::XML(client.get.body).xpath('/prestashop/api/*').collect { |resource| resource.name.to_sym }
    end

    # # # THIS NEEDS TO BE A NEW REQUESTOR TYPE
    # # # api.images.find('general/header') << this works
    # def image(*image_path)
    #   client[([:images]+image_path).join('/')].get.body
    # end

    def get(resource, *args)
      resource = normalize_resource(resource)
      raise RestClient::MethodNotAllowed unless resources.include?(resource)
      return image(*args) if resource == :images

      ids = extract_ids(args)
      params = extract_params(args)

      case ids
      when Array then get_resources(resource, ids, params)
      when NilClass then get_resource_ids(resource, params)
      when /^schema$/, /^synopsis$/ then generate_resource_object(resource, nil, params.merge({schema: :synopsis}))
      when /^blank$/ then generate_resource_object(resource, nil, params.merge({schema: :blank}), resource_class(resource))
      else get_resource(resource, ids, params, true)
      end
    end

    def method_missing(method, *args, &block)
      if resources.include?(resource = normalize_resource(method))
        resource_requestor(resource)
      else
        super
      end
    end

    private

    def resource_class(resource)
      resource_class_name = resource.to_s.classify
      "PrestaShop::#{resource_class_name}".safe_constantize || PrestaShop.const_set(resource_class_name, Class.new(PrestaShop::Resource))
    end

    def resource_requestors
      @resource_requestors ||= resources.zip({}).to_h
    end

    def resource_requestor(resource)
      resource = normalize_resource(resource)
      resource_requestors[resource] ||= ("PrestaShop::Requestor::#{resource.to_s.classify}".safe_constantize || PrestaShop::Requestor).new(
        api: self, resource_name: resource, schema: generate_resource_object(resource, nil, {schema: :synopsis}))
    end

    def resource_languages
      @resource_languages ||= resources.include?(:languages) ? get(:languages).zip({}).to_h : {}
    end

    def resource_language(language_id)
      resource_languages.include?(language_id) ? resource_languages[language_id] ||= get(:languages, language_id).name : language_id
    end

    def schema(resource)
      resource_requestor(resource).schema
    end

    def normalize_resource(resource)
      self.class.normalize_resource(resource)
    end

    def build_query_params(params)
      case
      when params.include?(:schema) then "?#{params.to_query}"
      when params.any? then "?date=1&#{params.map{ |k,v| ["filter[#{k}]", v] }.to_h.to_query}"
      end
    end

    def extract_ids(args)
      ids = args.dup
      ids.pop if ids.last.is_a? Hash
      ids = ids.first if ids.one? || ids.none?
      raise ArgumentError, 'invalid arguments' unless [NilClass, Numeric, String, Symbol, Array].any? { |klass| ids.is_a? klass }
      raise ArgumentError, 'invalid arguments' unless Array(ids).all? { |id| [Numeric, String, Symbol].any? { |klass| id.is_a? klass } }
      ids
    end

    def extract_params(args)
      args.last.is_a?(Hash) ? args.last : {}
    end

    def get_resource_ids(resource, params)
      xpath = XPATH_MAP.dig(resource, :list) || resource
      Nokogiri::XML(client[resource][build_query_params(params)].get.body).xpath("/prestashop/#{xpath}/*/@id").collect(&:value)
    end

    def get_resource(resource, id, params, raise_not_found_exception = false)
      begin
        generate_resource_object(resource, id, params, resource_class(resource), schema(resource))
      rescue RestClient::NotFound
        raise if raise_not_found_exception
        nil
      end
    end

    def get_resources(resource, ids, params = {})
      ids.uniq.sort.collect { |id| get_resource(resource, id, params) }.compact
    end

    def generate_resource_object(resource, id, params = {}, object_class = OpenStruct, object_schema = nil)
      xpath = XPATH_MAP.dig(resource, :find) || resource.to_s.singularize
      xml_response = Nokogiri::XML(client[resource][id][build_query_params(params)].get.body).remove_namespaces!.xpath("/prestashop/#{xpath}")
      resource_object = JSON.parse(Hash.from_xml(xml_response.to_s).values.first.to_json, object_class: object_class)
      resource_object.xml = xml_response
      resource_object.schema_synopsis = object_schema
      resource_object
    end

  end
end

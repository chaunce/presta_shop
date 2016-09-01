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

    def schemas
      @schemas ||= resources.zip({}).to_h
    end

    def schema(resource)
      schemas[resource] ||= generate_json_response(resource, '?schema=synopsis')
    end

    def image(*image_path)
      client[([:images]+image_path).join('/')].get.body
    end

    def get(resource, *args)
      resource = normalize_resource(resource)
      raise RestClient::MethodNotAllowed unless resources.include?(resource)
      return image(*args) if resource == :images

      ids = extract_ids(args)
      params = extract_params(args)

      case ids
      when Array then get_resources(resource, ids, params)
      when NilClass then get_resource_ids(resource, params)
      when /^schema$/, /^synopsis$/ then get_resource_synopsis(resource, params)
      when /^blank$/ then get_resource_blank(resource, params)
      else get_resource(resource, ids, params, true)
      end
    end

    def method_missing(method, *args, &block)
      if resources.include?(resource = normalize_resource(method))
        get(resource, *args)
      else
        super
      end
    end

    private

    def normalize_resource(resource)
      resource = resource.to_s.pluralize.to_sym
      resource = resource.to_s.singularize.to_sym if [:order_slips, :content_management_systems].include?(resource)
      resource
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
      args.last if args.last.is_a? Hash
    end

    def get_resource_ids(resource, params)
      xpath = XPATH_MAP.dig(resource, :list) || resource
      Nokogiri::XML(client[resource].get.body).xpath("/prestashop/#{xpath}/*/@id").collect(&:value)
    end

    def get_resource(resource, id, params, raise_not_found_exception = false)
      resource_class_name = resource.to_s.classify
      resource_class = "PrestaShop::#{resource_class_name}".safe_constantize || PrestaShop.const_set(resource_class_name, Class.new(PrestaShop::Resource))

      begin
        response = generate_json_response(resource, id, params, resource_class)
        response.schema_synopsis = schema(resource)
        response
      rescue RestClient::NotFound
        raise if raise_not_found_exception
        nil
      end
    end

    def get_resources(resource, ids, params = nil)
      ids.uniq.sort.collect { |id| get_resource(resource, id, params) }.compact
    end

    def get_resource_synopsis(resource, params = nil)
      generate_json_response(resource, '?schema=synopsis', params)
    end

    def get_resource_blank(resource, params = nil)
      generate_json_response(resource, '?schema=blank', params)
    end

    def generate_xml_response(resource, id, params = nil)
      xpath = XPATH_MAP.dig(resource, :find) || resource.to_s.singularize
      Nokogiri::XML(client[resource][id].get.body).remove_namespaces!.xpath("/prestashop/#{xpath}")
    end

    def generate_json_response(resource, id, params = nil, object_class = OpenStruct)
      JSON.parse(Hash.from_xml(generate_xml_response(resource, id, params).to_s).values.first.to_json, object_class: object_class)
    end

  end
end

module PrestaShop
  class Requestor
    include ActiveModel::Model
    attr_accessor :api, :resource_name, :schema
    alias_method :synopsis, :schema

    def find(id, *args)
      get(id, *args)
    end

    def list(*args)
      get(*args)
    end

    def blank(*args)
      get(:blank, *args)
    end

    def search(args)
      get(args.collect{ |k,v| ["filter[#{k}]", v] }.to_h.merge({date: 1}))
    end

    private

    def get(*args)
      api.get(self.resource_name, *args)
    end
  end
end

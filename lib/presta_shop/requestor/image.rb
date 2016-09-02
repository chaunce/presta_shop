module PrestaShop
  class Requestor
    class Image < PrestaShop::Requestor
      undef_method :schema, :synopsis, :blank, :search

      def find(*path)
        Raise NotImplementedError
        # this one should raise exception if the response is not an image file
        get(*path)
      end

      def list(*path)
        Raise NotImplementedError
        get(*args)
        Nokogiri::XML(api.client[:images].get.body).xpath("/prestashop/image_types/*").collect(&:name)
      end

      private

      def get(*args)
        api.get(self.resource_name, *args)
      end
    end
  end
end

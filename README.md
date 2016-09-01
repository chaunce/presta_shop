# PrestaShop

PrestaShop is a ruby gem to interact with a [Prestashop API](http://doc.prestashop.com/display/PS16/Using+the+PrestaShop+Web+Service)

this gem was originally forked from [Prestashopper](https://github.com/amatriain/prestashopper)

## Installation

add `presta_shop` Gemfile

```ruby
gem 'presta_shop'
```
    
## Usage

### verify PrestaShop api is enabled

```ruby
PrestaShop.api_enabled? 'my.prestashop.com'
 => true
```

### check api key is valid
```
PrestaShop.valid_key? 'my.prestashop.com', 'VALID_KEY'
 => true
```

### create a PrestaShop api object
```
api = PrestaShop::API.new 'my.prestashop.com', 'VALID_KEY'
```

### list resources available for the api key
```
api.resources
 => [:customers, :orders, :products] 
```

### get a list of ids for an available resource
```
order_ids = api.orders
 => [1, 2, 3, 4, 5, 6]
```

### get a specific resource by id
```
order = api.order 1
 => #<PrestaShop::Order id=1, ...>
```

### get an array of resources
```
order = api.orders 1, 2, 3
 => #<PrestaShop::Order id=1, ...>, #<PrestaShop::Order id=2, ...>, #<PrestaShop::Order id=3, ...>
```

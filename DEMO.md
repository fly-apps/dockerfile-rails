# Demo1

```
rails new welcome
cd welcome
echo 'Rails.application.routes.draw { root "rails/welcome#index" }' > config/routes.rb
bundle add dockerfile-rails --group development
bin/rails generate dockerfile
docker buildx build . -t rails-welcome
docker run -p 3000:3000 -e RAILS_MASTER_KEY=$(cat config/master.key) rails-welcome
```
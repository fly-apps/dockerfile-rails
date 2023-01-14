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

# Demo 2

```
rails new welcome --css tailwind --database postgresql
cd welcome

bin/rails generate model Visitor counter:integer
bin/rails generate controller Visitors counter
bin/rails generate channel counter

cat << 'EOF' > app/controllers/visitors_controller.rb
class VisitorsController < ApplicationController
  def counter
    @visitor = Visitor.find_or_create_by(id: 1)
    @visitor.update! counter: @visitor.counter.to_i + 1
    @visitor.broadcast_replace_later_to 'counter',
      partial: 'visitors/counter'
  end
end
EOF

cat << 'EOF' > app/views/visitors/counter.html.erb
<%= turbo_stream_from 'counter' %>

<div class="absolute top-0 left-0 h-screen w-screen mx-auto mb-3 bg-navy px-20 py-14 rounded-[20vh] flex flex-row items-center justify-center" style="background-color:rgb(36 24 91)">
  <img src="https://fly.io/static/images/brand/brandmark-light.svg" class="h-[50vh]" style="margin-top: -15px" alt="The monochrome white Fly.io brandmark on a navy background" srcset="">

  <div class="text-white" style="font-size: 40vh; padding: 10vh" data-controller="counter">
    <%= render "counter", visitor: @visitor %>
  </div>
</div>
EOF

cat << 'EOF' > app/views/visitors/_counter.html.erb
<%= turbo_frame_tag(dom_id visitor) do %>
  <%= visitor.counter.to_i %>
<% end %>
EOF

cat << 'EOF' > config/routes.rb
Rails.application.routes.draw { root "visitors#counter" }
EOF

bundle add dockerfile-rails --group development
bin/rails generate dockerfile --compose

docker compose build
docker compose up
```
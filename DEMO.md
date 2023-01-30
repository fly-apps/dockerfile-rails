If you have Rails and Docker installed on your machine, running each of these demos is a matter of opening a terminal window, navigating to an empty directory, and copy/pasting a block of instructions into that window.  Once started, navigate to http://localhost:3000/ to see the results.

# Demo 1 - Minimal

Rails provides a _smoke test_ for new applications that makes sure that you have your software configured correctly enough to serve a page.  The following deploys that smoke test in production.  Once done take a look at the `Dockerfile` file produced.

```bash
rails new welcome --minimal
cd welcome
echo 'Rails.application.routes.draw { root "rails/welcome#index" }' > config/routes.rb
bundle add dockerfile-rails --group development
bin/rails generate dockerfile
docker buildx build . -t rails-welcome
docker run -p 3000:3000 -e RAILS_MASTER_KEY=$(cat config/master.key) rails-welcome
```

Add `--load` to the `buildx` command if you want to save the image to local Docker.

# Demo 2 - Action Cable and Active Record

Real applications involve a network of services.  The following demo makes use of PostgreSQL and Redis to display a welcome screen with a live, updating, visitors counter. Once done, take a look at the `docker-compose.yml` file produced.

```bash
rails new welcome --database postgresql
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

<div style="position: absolute; top: 0; left: 0; height: 100vh; width: 100vw">
<svg width="100vw" height="100vh" viewBox="0 0 112 112" width="112" xmlns="http://www.w3.org/2000/svg">
<circle cx="56" cy="56" r="56" fill="#D30001"/>
<path d="m100.082357 48.9995403v4.1135034h-7.3003388v1.89854h3.6840717c1.9725091 0 4.0725341 1.4664311 4.1979971 3.9665124l.005913.2373977v1.5821167c-.087824 3.007959-2.5431211 4.1390018-4.0715389
4.2011773l-.1323712.0027328h-7.3907451v-4.0909018l7.4811518-.0226016v-1.9889467h-3.4806567c-1.7752583 0-4.0818321-1.3389153-4.2199942-3.9549201l-.0065176-.24899v-1.423905c0-2.6982402 2.2782129-4.182853 4.065464-4.2678491l.1610478-.003866zm-18.691579
0v11.8658752h6.1702551v4.1361051h-10.7357919v-16.0019803zm-6.4414751 0v16.0019803h-4.5881385v-16.0019803zm-15.210922 0h4.4073251l.187724.0066812c.0338609.0022735.0689457.0051499.1051601.0086643l.2300875.0290178c1.2913829.1985476 3.5463816 1.1213816
3.6751708 3.9068587l.0057677.2526881v11.7980702h-4.2717151v-2.8252084h-4.1361051v2.8252084h-4.4073251v-11.7980702c0-1.3184306 1.0040826-4.0468495 3.946899-4.197411zm-19.7398519-.0027581
8.5801857.0005749.2389234.0367462.1479459.029417.2741161.0653582.2125198.0599068.2323225.0747182c.0401793.0137704.0810402.0282201.122511.0433804l.2555691.0997376.2667618.1182852c1.3560515.6402866 3.0026855 2.0321583 3.0026855 5.016294 0 3.1830781-1.5465241
4.5014899-2.6988362 5.0420477l-.2109651.0925045-.1988828.0758655-.1839577.0608186-.1661898.0473636-.2097508.0493001-.2596493.0418363 5.0056895
5.0505836h-6.3749589l-3.7262083-3.8608906v3.8608906h-4.3098314zm22.0070603-3.0869193.4449917.4226807-.242968.1779881-.3482331.2693365-.1998573.1629204c-5.2398967-3.8745715-9.6476454-5.4221409-13.197119-5.8153537l-.5259807-.0504708c-1.0390742-.0842126-2.0007861-.0698101-2.8844302.0115462l-.4353132.0461111c-.0714668.0085662-.1423907.0175608-.2127712.0269653l-.4157595.0612005-.4026991.0701607-.3896194.0782415-.3765198.0854427c-.0616606.0147917-.1227746.0298468-.1833415.045147l-.3568339.0945957-.3436854.0995982-.3305174.1037213-.3173297.1069649-.3041225.109329-.2908956.1108137-.4115002.1670803-.5021902.2197615-.6533736.3088956-.610105.3005675c-4.6988866
2.6219788-6.8539294 6.8460711-7.7682002
10.8866463l-.1223101.5757838c-.0380504.1913833-.0734278.3821576-.1062732.5721301l-.0910804.5673196-.0767318.5613521-.0632275.5542277c-.0094594.0917134-.0183914.1830817-.0268134.2740808l-.044554.5413722-.0331601.5313556c-.0046242.0876603-.0088087.1748551-.0125713.2615602l-.0176525.5141618-.0083693.5012531.0000696.4871876.0140806.7018779.0283195.6637229.0397089.6216637.0482492.5756999.0539402.5258317.0758481.6167879.0741462.511937.0800002.4783756.0685995.3540863h-17.855317l.05849-.4417253.0463368-.2951448.0630206-.3647242.1132819-.5892069.1093787-.5150907.1820265-.7785088.1661376-.6486772.1259233-.4615943.2130474-.7338225.1589655-.5155042.1731728-.5354699.1879463-.5545226.2032857-.572662.2191913-.5898883.2356628-.6062014.2527004-.6216012c.043568-.1048328.0878694-.2102691.1329162-.3162901l.279318-.6429887.2977707-.6561056.3167894-.6683092.336374-.6795997.3565249-.689977c.3667889-.6948611.7646529-1.4039184
1.1961393-2.1230624 4.7463501-7.9105834 12.8377469-13.9000252 19.414832-14.4876686 5.0453806-.5054094 9.8925436.9276823 13.9443628
2.8796435l.6499858.3208582.6354768.3286093.6204019.335015c.1021126.0562949.2035736.1128007.304371.1694892l.5967286.3421013.580239.3451439.5631836.3468411.5455624.3471932.5273753.3461999.5086223.3438614c.0831762.0570406.1655475.1139277.247102.1706333l.479432.3378312.4592644.3321294.438531.3250825.4172317.3166902.5846736.4563569.5335674.4299071.6286237.5242179.6463432.5614015zm-30.7001056
14.5713243 2.4409801.881465c.1130083.8852319.2731034 1.7233771.4410464
2.4882761l.1013936.4499406-2.7122001-.9718717-.0338347-.2121618-.0660421-.4755843-.0611601-.5412195c-.0480285-.4774602-.0875814-1.0199003-.1101831-1.6188444zm31.5067239-7.6619652h-1.5143117c-.9400238
0-1.2391224.409772-1.3342901.670536l-.0282266.0950339c-.003237.014073-.0058266.0271526-.0078982.0390732l-.0081573.0715239-.0001295
3.9153864h4.1361051l-.0018533-3.9347694-.0102612-.0669913-.0257207-.0987241c-.0835357-.2591507-.3509135-.6910686-1.2052565-.6910686zm-50.4921242.339025 2.5991917.94927-.408641.9515839c-.2124882.4994644-.4277796 1.0148142-.6033575
1.457745l-.1180849.3028712-2.5991917-.94927.1323662-.3453033.2583889-.6392034.3057111-.7281974.3254875-.7536244c.0362438-.0827943.0723437-.1648823.1081297-.2458716zm35.4451209-.1434449h-3.4568439v3.6588673h3.4343968l.0547106-.025392.0865984-.0488983.1147536-.0786822c.2926428-.2211448.7316071-.7149797.7316071-1.6876847s-.4289878-1.4565634-.7149797-1.6710573l-.1121455-.0760741-.0846303-.0469301zm-15.4426456-.7606218
1.6273201 1.2882951c-.1808134.705172-.3182315 1.410344-.4122545 2.115516l-.0623806.528879-1.830735-1.4465067c.1808134-.81366.3842284-1.6499217.67805-2.4861834zm4.0004951-6.3058651 1.017075 1.5369134c-.3977893.4158707-.7666485.8317413-1.0950055
1.2707561l-.2384928.3339623-1.0848801-1.6273201c.40683-.5198383.8814651-1.0396767 1.4013034-1.5143117zm-16.1827936-3.3450467 1.6047183 1.4013034c-.40683.4237812-.8009465.8729894-1.1728146 1.3285542l-.3640987.4569775-1.7403284-1.4917101c.5198383-.5650416
1.08488-1.1300833 1.6725234-1.695125zm22.3982521-.0904067.4972366 1.4917101c-.5243586.162732-1.0487173.3688592-1.573076.6068095l-.393269.1842488-.5198384-1.559515c.5650417-.2486184 1.2204901-.4972367 1.9889468-.7232534zm5.28879-.54244c.5786027.0361627
1.1716705.1012555 1.7792033.2068505l.4583618.0869712-.0904067 1.4013034c-.596684-.1265694-1.193368-.2097435-1.790052-.2495224l-.447513-.0216976zm-18.5559686-6.2380601 1.017075
1.559515c-.4407325.2203663-.8687516.4661594-1.3031274.7278443l-.437201.2666291-1.0396767-1.5821167c.610245-.3616267 1.1978884-.67805
1.7629301-.9718717zm18.5107653.6328467.0904067-1.49171.4435073.1305564.3839803.1203252.3285458.1099079.2772037.0993048.3284915.128669.296488.1327112.1341451.0695838-.0904067
1.5143117c-.4821689-.1958811-.9643378-.381717-1.4532035-.5575078zm-8.5434301-2.8252084.4520333 1.3787017h-.2260167c-.4915862 0-.9831725.0127134-1.4747588.0476754l-.4915862.0427313-.4294317-1.3334984c.745855-.0904067 1.4691084-.13561 2.1697601-.13561z"
fill="#fff"/>
</svg>
</div>

<div style="position: absolute; font-size: 25vh; font-weight: bold; font-family: Calibre sans-serif; color: white; top: 65vh; left: 0; width: 100%; text-align: center">
<%= render "counter", visitor: @visitor %>
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

export RAILS_MASTER_KEY=$(cat config/master.key)
docker compose build
docker compose up
```

# Demo 3 - API only

This demo deploys a [Create React App](https://create-react-app.dev/) client and a Rails API-only server.  Ruby and Rails version information is retrieved from the server and displayed below a spinning React logo.  Note that the build process installs the
node moddules and ruby gems in parallel.

```bash
rails new welcome --api
cd welcome
npx -y create-react-app client

bin/rails generate controller Api versions

cat << 'EOF' > app/controllers/api_controller.rb
class ApiController < ApplicationController
  def versions
    render json: {
      ruby: RUBY_VERSION,
      rails: Rails::VERSION::STRING
    }
  end
end
EOF

cat << 'EOF' > client/src/App.js
import logo from './logo.svg';
import './App.css';
import React, { useState, useEffect } from 'react';

function App() {
  let [versions, setVersions] = useState('loading...');

  useEffect(() => {
    fetch('api/versions')
    .then(response => response.json())
    .then(versions => {
      setVersions(Object.entries(versions)
        .map(([name, version]) => `${name}: ${version}`).join(', ')
      )
    });
  });

  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <p>{ versions }</p>
      </header>
    </div>
  );
}

export default App;
EOF

bundle add dockerfile-rails --group development
bin/rails generate dockerfile

docker buildx build . -t rails-welcome
docker run -p 3000:3000 -e RAILS_MASTER_KEY=$(cat config/master.key) rails-welcome
```

# Demo 4 - Bunding Javascript (esbuild)

While optional, bundling Javascript is a popular choice, and starting with
Rails 7 there are three options: esbuild, rollup, and webpack.  The
the following demonstrates Rails 7 with esbuild:

```bash
rails new welcome --javascript esbuild
cd welcome

yarn add react react-dom
bin/rails generate controller Time index

cat <<-"EOF" >> app/javascript/application.js
import "./components/counter"
EOF

mkdir app/javascript/components

cat <<-"EOF" > app/javascript/components/counter.jsx
import React, { useState, useEffect, useRef } from 'react';
import { createRoot } from 'react-dom/client';

const Counter = ({ arg }) => {
  const [count, setCount] = useState(0);
  const countRef = useRef(count);
  countRef.current = count;

  useEffect(() => {
    const interval = setInterval(() => {
      setCount(countRef.current + 1);
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  return <div>{`${arg} - counter = ${count}!`}</div>;
};

document.addEventListener("DOMContentLoaded", () => {
  const container = document.getElementById("root");
  const root = createRoot(container);
  root.render(<Counter arg={`
    Ruby ${container.getAttribute('ruby')}
    Rails ${container.getAttribute('rails')}`} />);
});
EOF

cat <<-"EOF" > app/views/time/index.html.erb
<!DOCTYPE html>
<html>
<head>
<style>
body {
  margin: 0;
}

svg {
  height: 40vmin;
  pointer-events: none;
  margin-bottom: 1em;
}

@media (prefers-reduced-motion: no-preference) {
  svg {
    animation: App-logo-spin infinite 20s linear;
  }
}

main {
  background-color: #282c34;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  font-size: calc(10px + 2vmin);
  color: white;
}

@keyframes App-logo-spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
</head>
<body>
<main>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-11.5 -10.23174 23 20.46348">
  <title>React Logo</title>
  <circle cx="0" cy="0" r="2.05" fill="#61dafb"/>
  <g stroke="#61dafb" stroke-width="1" fill="none">
    <ellipse rx="11" ry="4.2"/>
    <ellipse rx="11" ry="4.2" transform="rotate(60)"/>
    <ellipse rx="11" ry="4.2" transform="rotate(120)"/>
  </g>
</svg>
<div id="root"
  ruby=<%= RUBY_VERSION %>
  rails=<%= Rails::VERSION::STRING %>>
</div>
</main>
</body>
</html>
EOF

cat <<-"EOF" > config/routes.rb
Rails.application.routes.draw { root "time#index" }
EOF

bundle add dockerfile-rails --group development
bin/rails generate dockerfile

docker buildx build . -t rails-welcome
docker run -p 3000:3000 -e RAILS_MASTER_KEY=$(cat config/master.key) rails-welcome
```

# Demo 5 - Grover / puppeteer / Chrome

This demo runs only on Intel hardware as Google doesn't supply Chrome
binaries for Linux on ARM.

```bash
rails new welcome --minimal
cd welcome
bundle add grover
npm install puppeteer

echo 'Rails.application.routes.draw { root "grover#pdf" }' > config/routes.rb

cat << 'EOF' > app/controllers/grover_controller.rb
class GroverController < ApplicationController
  def pdf
    grover = Grover.new('https://google.com', format: 'A4')
    send_data grover.to_pdf, filename: 'google.pdf', type: :pdf
  end
end
EOF

bundle add dockerfile-rails --group development
bin/rails generate dockerfile
docker buildx build . -t rails-welcome
docker run -p 3000:3000 -e RAILS_MASTER_KEY=$(cat config/master.key) rails-welcome
```

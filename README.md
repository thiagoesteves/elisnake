![github workflow](https://github.com/thiagoesteves/elisnake/workflows/Elixir%20Develop/badge.svg)
[![Erlant/OTP Release](https://img.shields.io/badge/Erlang-OTP--25.0-green.svg)](https://github.com/erlang/otp/releases/tag/OTP-24.0)

# Game webserver written in Elixir
![Erlgame](/doc/elisnake_snake.png)

The app has the same core game written in [Erlang](https://github.com/thiagoesteves/erlgame) but translated to Elixir. It is part of the transition studies from Erlang Programming language to Elixir.

## Compile and run the application
```
mix deps.get
iex -S mix
```

Once running, you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Deploy [Docker]

### Create a docker image to deploy
The next command will create and publish your application image into the docker
```
make docker.build
```

### Deploy using helm (Running locally)
```
make local.deploy.install
```

### Uninstall deployment
```
make local.deploy.uninstall
```
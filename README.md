![github workflow](https://github.com/thiagoesteves/elisnake/workflows/Elixir%20Develop/badge.svg)
![ubuntu-20.04](https://actionvirtualenvironmentsstatus.azurewebsites.net/api/status?imageName=ubuntu20&badge=1)

# Elisnake

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
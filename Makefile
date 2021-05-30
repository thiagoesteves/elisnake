MIX_ENV=prod

##########################################################
#    Application Commands - Release, Compile, etc        #
##########################################################

clean:
	mix deps.clean --all

compile:
	mix deps.get
	mix deps.compile
	mix compile

release: clean compile
	mix deps.get --only prod
	MIX_ENV=${MIX_ENV} mix compile

#	Release
	MIX_ENV=${MIX_ENV} mix do phx.digest, distillery.release --env=${MIX_ENV}
	@echo "Release for MIX_ENV=${MIX_ENV} is done !"

upgrade: compile
#	Release 
	MIX_ENV=${MIX_ENV} mix do phx.digest, distillery.release --env=${MIX_ENV} --upgrade
	@echo "Upgrade for MIX_ENV=${MIX_ENV} is ready to be used !"

mkdir -p "$JUPYTER_DIRECTORY"
mkdir -p "$JUPYTER_DIRECTORY/oscar-tutorial"

jupyter lab --ServerApp.allow_root=True --Session.username=root --ServerApp.base_url="$JHUB_BASE_URL" --IdentityProvider.token="$JUPYTER_TOKEN" --ServerApp.root_dir="$JUPYTER_DIRECTORY" --ip=0.0.0.0 --no-browser

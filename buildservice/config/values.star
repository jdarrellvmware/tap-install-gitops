load("@ytt:data", "data")
load("@ytt:base64", "base64")
load("@ytt:json", "json")
load("@ytt:assert", "assert")

data.values.kp_default_repository or assert.fail("missing kp_default_repository")
data.values.kp_default_repository_username or assert.fail("missing kp_default_repository_username")
data.values.kp_default_repository_password or assert.fail("missing kp_default_repository_password")

# validate mutually exclusive settings are not set
exclusive = [data.values.pull_from_tanzunet, data.values.pull_from_kp_default_repo, data.values.pull_secret_export, data.values.tbs_source_registry]
found = False;
for v in exclusive:
	if v:
		if found:
			assert.fail("only one of pull_from_tanzunet, pull_from_kp_default_repo, and pull_secret_export can be set. If any are set, tbs_source_* should not be set.")
		end
		found = True
	end
end

pull_secret_export=data.values.pull_secret_export
if not found:
	pull_secret_export=True
end

# extract the docker registry from the repository string
kp_default_registry = ""
parts = data.values.kp_default_repository.split("/", 1)
if len(parts) == 2:
    if ('.' in parts[0] or ':' in parts[0]) and parts[0] != "index.docker.io":
        kp_default_registry = parts[0]
    else:
        kp_default_registry = "https://index.docker.io/v1/"
    end
elif len(parts) == 1:
	assert.fail("kp_default_repository must be a valid writeable repository and must include a '/'")
end

kp_default_docker_auth = base64.encode("{}:{}".format(data.values.kp_default_repository_username, data.values.kp_default_repository_password))
kp_default_docker_creds = {"username": data.values.kp_default_repository_username, "password": data.values.kp_default_repository_password, "auth": kp_default_docker_auth}
kp_default_docker_configjson = base64.encode(json.encode({"auths": {kp_default_registry: kp_default_docker_creds}}))

# set defaults for tbs_source creds
tbs_source_registry=data.values.tbs_source_registry
tbs_source_registry_username=data.values.tbs_source_registry_username
tbs_source_registry_password=data.values.tbs_source_registry_password

if data.values.pull_from_kp_default_repo:
	tbs_source_registry = kp_default_registry
    tbs_source_registry_username = data.values.kp_default_repository_username
    tbs_source_registry_password = data.values.kp_default_repository_password
end

if data.values.pull_from_tanzunet:
	if not data.values.tanzunet_username or not data.values.tanzunet_password:
		assert.fail("tanzunet_username and tanzunet_password must be set to install directly from tanzunet")
	end
	tbs_source_registry = "registry.tanzu.vmware.com"
    tbs_source_registry_username = data.values.tanzunet_username
    tbs_source_registry_password = data.values.tanzunet_password
end

tbs_source_registry or pull_secret_export or assert.fail("missing tbs_source_registry. must be set or use one of pull_from_kp_default_repo=true, pull_from_tanzunet=true, pull_secret_export=true")
tbs_source_registry_username or pull_secret_export or assert.fail("missing tbs_source_registry_username. must be set or use one of pull_from_kp_default_repo=true, pull_from_tanzunet=true, pull_secret_export=true")
tbs_source_registry_password or pull_secret_export or assert.fail("missing tbs_source_registry_password. must be set or use one of pull_from_kp_default_repo=true, pull_from_tanzunet=true, pull_secret_export=true")

tbs_source_docker_auth = base64.encode("{}:{}".format(tbs_source_registry_username, tbs_source_registry_password))
tbs_source_docker_creds = {"username": tbs_source_registry_username, "password": tbs_source_registry_password, "auth": tbs_source_docker_auth}
tbs_source_docker_configjson = base64.encode(json.encode({"auths": {tbs_source_registry: tbs_source_docker_creds}}))

kpack_source_docker_configjson = tbs_source_docker_configjson
cert_injection_webhook_source_docker_configjson = tbs_source_docker_configjson

# require descriptor_name to be set when using dependency updater
if (data.values.tanzunet_username and data.values.tanzunet_password) and not data.values.descriptor_name:
    assert.fail("descriptor_name must be set")
end

values = data.values

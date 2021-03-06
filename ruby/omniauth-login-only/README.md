# Ruby OmniAuth - Simple Login Only

This folder contains a very simple Ruby web app to allow a user to "Login with Cloud Foundry" using your own UAA. You can run the script using Docker or your local Ruby environment.

## Deploy UAA

If you do not have access to a dev/test UAA, you can easily run your own.

* https://github.com/starkandwayne/uaa-deployment-cf - run a production-ready UAA on any Cloud Foundry, using either PostgreSQL or MySQL service instance; also allows for you to customize the HTML theme for your UAA

    To target and authorize the `uaa` CLI to your UAA:

    ```text
    source <(path/to/uaa-deployment-cf/bin/u env)
    u auth-client

    echo $UAA_URL
    ```

* https://github.com/starkandwayne/uaa-deployment - run a UAA on your local VirtualBox, or a production-ready UAA on any cloud infrastructure using BOSH

    To target and authorize the `uaa` CLI to your UAA:

    ```text
    source <(path/to/uaa-deployment/bin/u env)
    u auth-client

    echo $UAA_URL
    echo $UAA_CA_CERT_FILE
    ```

* https://github.com/cloudfoundry-incubator/cfdev - run a local Cloud Foundry, with its UAA, on your local machine using LinuxKit

    To install the [`uaa`](https://github.com/cloudfoundry-incubator/uaa-cli/) CLI, see https://github.com/starkandwayne/uaa-cli-releases#readme

    To target and authorize the `uaa` CLI to your UAA:

    ```text
    uaa target https://uaa.v3.pcfdev.io/ --skip-ssl-validation
    uaa get-client-credentials-token admin -s admin-client-secret

    source <(cf dev bosh env)
    export UAA_URL=https://login.v3.pcfdev.io
    export UAA_CA_CERT=$(bosh int <(bosh -d cf manifest) --path /instance_groups/name=api/jobs/name=routing-api/properties/uaa/ca_cert)
    tmp=$(mktemp -d)
    export UAA_CA_CERT_FILE=$tmp/uaa.ca
    echo "$UAA_CA_CERT" > ${UAA_CA_CERT_FILE}
    ```

## Setup

First, create a UAA client:

```text
uaa create-client omniauth-login-only -s omniauth-login-only \
  --authorized_grant_types authorization_code,refresh_token \
  --scope openid \
  --redirect_uri http://localhost:9292/auth/cloudfoundry/callback,http://127.0.0.1:9292/auth/cloudfoundry/callback
```

Create a UAA user with which to authenticate in the browser:

```text
uaa create-user drnic -v \
  --email drnic@starkandwayne.com \
  --givenName "Dr Nic" \
  --familyName "Williams" \
  --password drnic_secret
```

Check that `$UAA_URL` related env vars are setup (this is done automatically via `source <(.../u env)` above, or manually)

```text
$ env | grep UAA
UAA_URL=https://192.168.50.6:8443
UAA_CA_CERT=-----BEGIN CERTIFICATE----- ...
UAA_CA_CERT_FILE=/var/folders/wd/xnncwqp96rj0v1y2nms64mq80000gn/T/tmp.biR9hDnr/ca.pem
```

## Run the server

You can run the Ruby server using Docker or your local Ruby environment.

With Docker:

```text
docker run -ti -p 9292:9292 -e UAA_URL=$UAA_URL -e UAA_CA_CERT=$UAA_CA_CERT \
    starkandwayne/uaa-example-omniauth-login-only
```

With Ruby:

```text
git clone https://github.com/starkandwayne/ultimate-guide-to-uaa-examples
cd ultimate-guide-to-uaa-examples/ruby/omniauth-login-only
bundle
bundle exec rackup
```

Visit http://localhost:9292, click "Sign in with Cloud Foundry", and commence the login sequence to be redirected to the UAA.

Login as your UAA users (e.g. `drnic` and `drnic_secret`).

As this user, authorize the UAA to allow the `omniauth-login-only` client to "Access profile information, i.e. email, first and last name, and phone number":

![omniauth-login-only-authorization](omniauth-login-only-authorization.png)

You are then returned to the `omniauth-uaa-oauth2` sample application.

It will output the data returned from the UAA response token, for example:

```json
{"provider":"cloudfoundry","uid":"10661d47-6d08-4872-81aa-7868327cff0b","info":{"name":"Dr Nic Williams","email":"drnic@starkandwayne.com","first_name":"Dr Nic","last_name":"Williams"},"credentials":{"token":"eyJhbGciOiJSUzI1NiIsImtpZCI6ImxlZ2FjeS10b2tlbi1rZXkiLCJ0eXAiOiJKV1QifQ.eyJqdGkiOiIwMDcyMDY1NThjYjM0ODJmYjExMDk4NjM3OTQ0MTQ3ZCIsIm5vbmNlIjoiODdlY2FhMGRmNTRhZmE2YmVlMTRmYzQyYWE0NDBkNTciLCJzdWIiOiIxMDY2MWQ0Ny02ZDA4LTQ4NzItODFhYS03ODY4MzI3Y2ZmMGIiLCJzY29wZSI6WyJvcGVuaWQiXSwiY2xpZW50X2lkIjoib21uaWF1dGgtZXhhbXBsZSIsImNpZCI6Im9tbmlhdXRoLWV4YW1wbGUiLCJhenAiOiJvbW5pYXV0aC1leGFtcGxlIiwiZ3JhbnRfdHlwZSI6ImF1dGhvcml6YXRpb25fY29kZSIsInVzZXJfaWQiOiIxMDY2MWQ0Ny02ZDA4LTQ4NzItODFhYS03ODY4MzI3Y2ZmMGIiLCJvcmlnaW4iOiJ1YWEiLCJ1c2VyX25hbWUiOiJkcm5pYyIsImVtYWlsIjoiZHJuaWNAc3RhcmthbmR3YXluZSIsImF1dGhfdGltZSI6MTUzMDI3MDI1MiwicmV2X3NpZyI6Ijg0MmQ5N2RkIiwiaWF0IjoxNTMwMjcxMDM2LCJleHAiOjE1MzAzMTQyMzYsImlzcyI6Imh0dHBzOi8vMTkyLjE2OC41MC42Ojg0NDMvb2F1dGgvdG9rZW4iLCJ6aWQiOiJ1YWEiLCJhdWQiOlsib3BlbmlkIiwib21uaWF1dGgtZXhhbXBsZSJdfQ.rdkpQmvYXUWKTf28Go24-Vju7rkGLRzgXQfBWV5vTOzMxbNdbwdmhyCciahi1gbFyR-XzaHtboOK0vF2VX8BPd9_6zfB_DoVbQb3SV-QyOFVDbUNOQ68GGpw0ct2KsTxKeIygf_2kEfmZ4nQ6W83taWJU6cFMEOUI-Z3vUzPD09_HCBuTkOj2Nr9EdenrnFZcnu4y5r6Pw8YdE9KGoJnMiPfMYF1ilBzafDg85t_Wy6aplZr5GWpQrJhSUUokQZ1wKUwzEj_YzDV9FWmUzAqMJxEuXDcUkKegCI394qhyHjel20G_nSPrp8nWaSC8ee1RyNtIP1efBPOx5iF8qGGGg","refresh_token":"eyJhbGciOiJSUzI1NiIsImtpZCI6ImxlZ2FjeS10b2tlbi1rZXkiLCJ0eXAiOiJKV1QifQ.eyJqdGkiOiJmY2I4NzZlM2NlNDI0MjZlODc0ODIwMDQxZjFmMWRkMy1yIiwic3ViIjoiMTA2NjFkNDctNmQwOC00ODcyLTgxYWEtNzg2ODMyN2NmZjBiIiwic2NvcGUiOlsib3BlbmlkIl0sImlhdCI6MTUzMDI3MTAzNiwiZXhwIjoxNTMyODYzMDM2LCJjaWQiOiJvbW5pYXV0aC1leGFtcGxlIiwiY2xpZW50X2lkIjoib21uaWF1dGgtZXhhbXBsZSIsImlzcyI6Imh0dHBzOi8vMTkyLjE2OC41MC42Ojg0NDMvb2F1dGgvdG9rZW4iLCJ6aWQiOiJ1YWEiLCJncmFudF90eXBlIjoiYXV0aG9yaXphdGlvbl9jb2RlIiwidXNlcl9uYW1lIjoiZHJuaWMiLCJvcmlnaW4iOiJ1YWEiLCJ1c2VyX2lkIjoiMTA2NjFkNDctNmQwOC00ODcyLTgxYWEtNzg2ODMyN2NmZjBiIiwicmV2X3NpZyI6Ijg0MmQ5N2RkIiwiYXVkIjpbIm9wZW5pZCIsIm9tbmlhdXRoLWV4YW1wbGUiXX0.ky1_EzIE0uVW2jNHeAS6crKIACM4LmN53IHUaHqT3acwUKc4aj_Ob2kClbPIZqeBycYe59I7zEfu5A0BwwcZy2ZrSaEGS34h8JmTqDLvgIDusz2DkaHHZ9xSeZooi9czLih-1JMMJVDZFbr_thtZiq6UqRdZTvpCMPTiF6pS8Pu0BYhjGFt2TZOuq9RkSMRC1L026HCmPAE-Z44UlWFj5mJ-B4nC9qeJKg4Doc05I8WV7_rWI_7yyDTyJ4W0A1k-18SyS_gb7aVfD0BWbu_PKQjmmx7XPHwcxlaSw0xcBcbJlQ7BVS4l3_GcjEZYYiZirAuhNAf8JHEBmxC_SVkpnA","authorized_scopes":"openid"},"extra":{"raw_info":{"user_id":"10661d47-6d08-4872-81aa-7868327cff0b","sub":"10661d47-6d08-4872-81aa-7868327cff0b","user_name":"drnic","given_name":"Dr Nic","family_name":"Williams","email":"drnic@starkandwayne.com","previous_logon_time":1530168890029,"name":"Dr Nic Williams"}}}
```

If you repeat the sequence and visit http://localhost:9292, and click "Sign in with Cloud Foundry" link, you will automatically be returned to the result above.

Why? The browser still redirected you to your UAA, but since you are now already logged in it does not prompt you to login. It also does not need to ask you if you want to authorize the `omniauth-login-only` UAA client to access your personal information since you've already granted this access. So the UAA can immediately return you back to your `omniauth-uaa-oauth2` application.

## Docker

```text
docker build -t starkandwayne/uaa-example-omniauth-login-only .
docker run -ti -p 9292:9292 -e UAA_URL=$UAA_URL -e UAA_CA_CERT=$UAA_CA_CERT \
    starkandwayne/uaa-example-omniauth-login-only
```
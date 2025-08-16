# ProtonVPN Docker Image
This fork implements several improvements and Proton API-based authentication (which is now mandatory to run).

- Improved parsing of OpenVPN extra arguments passed through OPENVPN_EXTRA_ARGS env in Docker. In several cases, e.g, when argument contain quoted string with spaces, parsing fould fail previously
- Implemented Proton API to authenticate and fetch the server list (old, unauthenticated fetch would fail otherwise)
   - New env variables (`PROTON_USERNAME` and `PROTON_PASSWORD`) are required to be set to supply the Proton account username and password for API authentication.
- Proton occasionally blocks API calls without a captcha. In that case, container scripts will re-use the last valid list of proton servers it obtained through API authentication.
- In  case the API call is blocked/failed during the first run, or it never got a valid server list through API, then the container script will fetch a fallback list of proton servers (which I maintain and update manually on GitHub). Alternate backup list url can be provided with `PROTON_BACKUP_LOGICALS` env variable
- These steps ensure the container never fails to start due to API fail/block. All these decision steps are logged during the container run.
- Other minor changes
  - Now the default Proton tier is 'free'.
  - Fixed error handling if OLD IP check failed (Previously script would terminate). Now script will log and disable IP checking.
  - To skip IP checking, any invalid value will work; a simple 'XX' would stop IP checking.

  
## Features

- **Minimal Footprint:** Built on Alpine Linux for a compact image size.
- **Flexible Server Selection:** Use JQ filters for granular control over servers with random selection.
- **Automatic Server Rotation (Optional):** Schedule automatic reconnection to switch servers periodically.
- **Multi-Container Support:** Easily connect any number of containers to the VPN.
- **Kill Switch:** Disconnect containers on VPN drop.
- **HTTP Proxy (Optional):** Easily route any http and https traffic through the VPN.

## Usage

1. **Obtain OpenVPN Credentials:** Get your credentials from your ProtonVPN
   account: [https://account.proton.me/u/0/vpn/OpenVpnIKEv2](https://account.proton.me/u/0/vpn/OpenVpnIKEv2).
2. **Configure Credentials:** Choose one of the following methods:
   - **Secrets File:** Create a file containing your username and password on separate lines. Set
     the `AUTH_USER_PASS_FILE` environment variable to the file path.
   - **Environment Variables:** Define the `OPENVPN_USER` and `OPENVPN_PASS` environment variables with your
     credentials.
3. **Connect Containers and/or Enable HTTP Proxy:**
   - **VPN Access:** Use the `network_mode: service:protonvpn` option in your Docker Compose configuration for
     containers requiring VPN protection.
   - **HTTP Proxy:** Set the `HTTP_PROXY` environment variable to `1` and map port `3128` to use the VPN in any
     application with HTTP(S) proxy support.

> [!IMPORTANT]
> Since containers share the network stack when using `network_mode`, the port mappings for services requiring external
> access need to be defined on the ProtonVPN container.

### Example Docker Compose with other Container

```yaml
services:
  protonvpn:
    image: genericmale/protonvpn
    restart: unless-stopped
    environment:
      - PROTON_USERNAME=login.username
      - PROTON_PASSWORD=login.password
      - OPENVPN_USER=openvpn.user
      - OPENVPN_PASS=openvpn.password
      - VPN_RECONNECT=2:00
      - VPN_SERVER_COUNT=10
    ports:
      - 8118:8118 # Privoxy Port
    volumes:
      - /etc/localtime:/etc/localtime:ro
    devices:
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    secrets:
      - protonvpn
  privoxy:
    image: vimagick/privoxy
    restart: unless-stopped
    network_mode: service:protonvpn
    depends_on:
      protonvpn:
        condition: service_healthy
secrets:
  protonvpn:
    file: protonvpn.auth
```

This configuration achieves the following:

- Uses `VPN_SERVER_COUNT=10` to randomly selects one of the 10 fastest servers.
- Schedules reconnection at 2:00 AM with `VPN_RECONNECT=2:00` to rotate servers.
- Runs a Privoxy container attached to the VPN network. (`network_mode: service:protonvpn`)
- Privoxy is not started until the VPN is connected with `depends_on` and `condition: service_healthy`.
- Exposes Privoxy's port (8118) for clients to connect to the VPN using Privoxy as a forward proxy.
  Notice the port mapping on the ProtonVPN container.

### Example Docker Compose using built-in Proxy

```yaml
services:
  protonvpn:
    image: genericmale/protonvpn
    restart: unless-stopped
    environment:
      - PROTON_USERNAME=login.username
      - PROTON_PASSWORD=login.password
      - OPENVPN_USER_PASS_FILE=/run/secrets/protonvpn
      - HTTP_PROXY=1
    ports:
      - 3128:3128
    volumes:
      - /etc/localtime:/etc/localtime:ro
    devices:
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    secrets:
      - protonvpn
secrets:
  protonvpn:
    file: protonvpn.auth
```

### Environment Variables

| Variable               | Default                     | Description                                                                                                                                  |
|------------------------|-----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| OPENVPN_USER_PASS_FILE | /etc/openvpn/protonvpn.auth | Path to a file containing your OpenVPN username and password on separate lines.                                                              |
| PROTON_USERNAME        | *(undefined)*               | Username for Proton account login.                                                                                                           |
| PROTON_PASSWORD        | *(undefined)*               | Password for Proton account login.                                                                                                           |
| OPENVPN_USER           | *(undefined)*               | Username for OpenVPN authentication. Will be used to create `OPENVPN_USER_PASS_FILE` if it doesn't exist.                                    |
| OPENVPN_PASS           | *(undefined)*               | Password for OpenVPN authentication. Will be used to create `OPENVPN_USER_PASS_FILE` if it doesn't exist.                                    |
| OPENVPN_EXTRA_ARGS     | *(undefined)*               | Additional arguments to pass to the OpenVPN command.                                                                                         |
| PROTON_TIER            | 0                           | Your Proton Tier. Valid values: 0 (Free), 1 (Basic), 2 (Plus), 3 (Visionary)                                                                 |
| IP_CHECK_URL           | <https://ifconfig.co/json>  | URL to check for a new IP address after connecting to the VPN. Unset to disable.                                                             |
| CONNECT_TIMEOUT        | 60                          | Maximum time in seconds to wait for a new IP before a reconnect is triggered.                                                                |
| VPN_SERVER_FILTER      | .                           | Optional JQ filter to apply to the server list returned by the API. By default, servers are ranked by their score (closest/fastest on top).  |
| VPN_SERVER_COUNT       | 1                           | Number of top servers (from the filtered list) to pass to OpenVPN. One server from this list will be randomly chosen for connection.         |
| VPN_RECONNECT          | *(undefined)*               | Optional time to schedule automatic reconnection. Either HH:MM for a daily reconnect at a fixed time, or a duration to wait (e.g. 30m, 12h). |
| VPN_KILL_SWITCH        | 1                           | When enabled (1), disconnects the network when the VPN drops. Set to 0 to disable.                                                           |
| HTTP_PROXY             | 0                           | When enabled (1), starts tinyproxy on port 3128.                                                                                             |

### JQ Filters for Advanced Server Selection

The `VPN_SERVER_FILTER` environment variable allows you to filter available ProtonVPN servers using JQ queries.

Some examples:

```yaml
# Fastest Servers from Germany
- VPN_SERVER_FILTER=map(select(.ExitCountry == "DE"))

# Servers with Lowest Load
- VPN_SERVER_FILTER=sort_by(.Load)

# Specific server
- VPN_SERVER_FILTER=map(select(.Name == "GR#3"))

# Fastest Servers from Berlin with Load <50%
- VPN_SERVER_FILTER=map(select(.City == "Berlin" and .Load < 50))

# Fastest Servers from Different Countries
- VPN_SERVER_FILTER=group_by(.ExitCountry) | map(.[0]) | sort_by(.Score)

```

## Building

To build the image, the following command can be used (adapt tag name to your liking):

```sh
docker image build . -t protonvpn
```

## Additional Resources

- Docker Compose Overview: <https://docs.docker.com/compose/>
- ProtonVPN Documentation: <https://protonvpn.com/support/linux-openvpn/>
- OpenVPN Reference Manual: <https://openvpn.net/community-resources/reference-manual-for-openvpn-2-6/>
- Tinyproxy: <https://tinyproxy.github.io/>
- JQ Manual: <https://jqlang.github.io/jq/manual/>

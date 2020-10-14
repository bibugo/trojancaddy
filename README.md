# trojancaddy

```bash
docker run -d --name trojancaddy \
	-v /path/to/trojancaddy:/srv \
	-p 8443:443 -p 8080:80 \
	-e PUID={uid} -e PGID={gid} \
	-e DOMAIN={your domain} \
	-e CFTOKEN={your cloudflare api token} \
	-e NAIVEUSER={naiveproxy username} \
	-e NAIVEPASS={naiveproxy password} \
	-e TROJANPASS={trojan password} \
	bibugo/trojancaddy
```

OR

```bash
docker run -d --name trojancaddy \
	-v /path/to/trojancaddy:/srv \
	--net=macvlan --ip=11.11.11.11 \
	-e PUID={uid} -e PGID={gid} \
	-e DOMAIN={your domain} \
	-e CFTOKEN={your cloudflare api token} \
	-e NAIVEUSER={naiveproxy username} \
	-e NAIVEPASS={naiveproxy password} \
	-e TROJANPASS={trojan password} \
	bibugo/trojancaddy
```

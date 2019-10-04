FROM debian:buster-slim

LABEL maintainer="Simon Castano <simon@brane.cc>"

ARG VERSION
ARG DEBIAN_FRONTEND=noninteractive

ENV PGP_KEY 01EA5486DE18A882D4C2684590C8019E36C2E964

WORKDIR /tmp

RUN set -ex \
	# Install OS utilities
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
	apt-utils \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
	ca-certificates \
	dirmngr \
	gosu \
	gpg-agent \
	gpg \
	wget \
	# Get latest Bitcoin Core version is not set at build and set variables
	&& if [ -z "$VERSION" ]; then \
	VERSION=$(wget -q https://bitcoincore.org/en/releasesrss.xml -O - | grep -m1 "Bitcoin Core " | sed 's/[^0-9.]//g'); \
	fi; \
	FNAME="bitcoin-$VERSION-x86_64-linux-gnu.tar.gz" \
	&& TAR_URL="https://bitcoincore.org/bin/bitcoin-core-$VERSION/$FNAME" \
	&& ASC_URL="https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS.asc" \
	# Download binaries and verify checksum
	&& wget -q $TAR_URL \
	&& wget -q $ASC_URL \
	&& sha256sum --ignore-missing --check SHA256SUMS.asc \
	# Reliably fetch the PGP key and verify checksum file signature
	&& found=''; \
	for server in \
	hkp://keyserver.ubuntu.com:80 \
	ha.pool.sks-keyservers.net \
	hkp://p80.pool.sks-keyservers.net:80 \
	ipv4.pool.sks-keyservers.net \
	keys.gnupg.net \
	pgp.mit.edu \
	; do \
	echo "Fetching GPG key $PGP_KEY from $server"; \
	gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$PGP_KEY" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch PGP key $PGP_KEY" && exit 1; \
	gpg --verify SHA256SUMS.asc \
	# Extract Bitcoin Core binaries
	&& tar -xzvf $FNAME -C /usr/local --strip-components=1 --exclude=*-qt \
	# Clean
	&& apt-get purge --auto-remove -y \
	apt-utils \
	ca-certificates \
	dirmngr \
	gpg-agent \
	gpg \
	wget \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /tmp/* \
	# Create bitcoin user and group
	&& groupadd bitcoin \
	&& useradd -g bitcoin -m -d /bitcoin bitcoin

VOLUME ["/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333

WORKDIR /bitcoin

# Copy startup script
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["bitcoind"]

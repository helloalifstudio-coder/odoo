# Build Odoo from this checkout (not from an unrelated prebuilt Odoo image).
FROM ubuntu:24.04

LABEL org.opencontainers.image.title="Odoo Community 20.0"
LABEL org.opencontainers.image.description="Local source build for the Alif Odoo fork"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HOME=/var/lib/odoo \
    PATH=/opt/odoo-venv/bin:${PATH}

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl fonts-dejavu-core fonts-liberation fonts-noto-cjk \
    fonts-symbola build-essential node-less nodejs npm python3 python3-dev \
    python3-pip python3-venv libffi-dev libjpeg-dev libldap2-dev libmagic1 \
    libpq-dev libssl-dev libxml2-dev libxslt1-dev libsasl2-dev zlib1g-dev \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Odoo's patched wkhtmltopdf build with upstream checksums.
RUN set -eux; \
    ARCH="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "${ARCH}" in \
      amd64) WKHTML_ARCH="amd64"; WKHTML_SHA="967390a759707337b46d1c02452e2bb6b2dc6d59" ;; \
      arm64) WKHTML_ARCH="arm64"; WKHTML_SHA="90f6e69896d51ef77339d3f3a20f8582bdf496cc" ;; \
      *) echo "Unsupported architecture for the pinned wkhtmltopdf build: ${ARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/wkhtmltox.deb \
      "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${WKHTML_ARCH}.deb"; \
    echo "${WKHTML_SHA}  /tmp/wkhtmltox.deb" | sha1sum -c -; \
    apt-get update; \
    apt-get install -y --no-install-recommends /tmp/wkhtmltox.deb; \
    rm -rf /var/lib/apt/lists/* /tmp/wkhtmltox.deb

RUN npm install --global rtlcss \
    && npm cache clean --force \
    && apt-get purge -y npm \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/odoo-requirements.txt
RUN python3 -m venv /opt/odoo-venv \
    && /opt/odoo-venv/bin/pip install --no-cache-dir --upgrade pip wheel \
    && /opt/odoo-venv/bin/pip install --no-cache-dir -r /tmp/odoo-requirements.txt \
    && rm -f /tmp/odoo-requirements.txt

RUN useradd --system --uid 10001 --user-group --home-dir /var/lib/odoo --create-home odoo \
    && mkdir -p /opt/odoo /var/log/odoo /mnt/extra-addons \
    && chown -R odoo:odoo /var/lib/odoo /var/log/odoo /mnt/extra-addons

COPY --chown=odoo:odoo . /opt/odoo
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/odoo-entrypoint

WORKDIR /opt/odoo
USER odoo

EXPOSE 8069 8072

ENTRYPOINT ["/usr/local/bin/odoo-entrypoint"]
CMD []

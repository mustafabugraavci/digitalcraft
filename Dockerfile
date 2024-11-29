FROM node:12.21.0-buster-slim as base

# This image is NOT made for production use.
LABEL maintainer="Eero Ruohola <eero.ruohola@shuup.com>"

RUN apt-get update && apt-get install -y \
    build-essential \
    python3-dev \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get --assume-yes install \
        libpangocairo-1.0-0 \
        python3 \
        python3-dev \
        python3-pil \
        python3-pip \
        curl \
    && rm -rf /var/lib/apt/lists/ /var/cache/apt/

#RUN apt-get install -y cargo

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add .cargo/bin to PATH
ENV PATH="/root/.cargo/bin:${PATH}"

# Check cargo is visible
RUN rustup update

RUN pip3 install cryptography==3.4.7

RUN pip3 install markupsafe==2.0.1

# These invalidate the cache every single time but
# there really isn't any other obvious way to do this.
COPY . /app
WORKDIR /app

# The dev compose file sets this to 1 to support development and editing the source code.
# The default value of 0 just installs the demo for running.
ARG editable=0

RUN if [ "$editable" -eq 1 ]; then pip3 install -r requirements-tests.txt && python3 setup.py build_resources; else pip3 install shuup; fi

RUN python3 -m shuup_workbench migrate
RUN python3 -m shuup_workbench shuup_init

RUN echo '\
from django.contrib.auth import get_user_model\n\
from django.db import IntegrityError\n\
try:\n\
    get_user_model().objects.create_superuser("admin", "admin@admin.com", "admin")\n\
except IntegrityError:\n\
    pass\n'\
| python3 -m shuup_workbench shell

CMD ["python3", "-m", "shuup_workbench", "runserver", "0.0.0.0:8000"]

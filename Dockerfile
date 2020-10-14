FROM hashicorp/terraform:0.13.3
WORKDIR /app
COPY main.tf /app/
RUN terraform init

RUN apk add --no-cache python3 bash autossh openssh-client
RUN mkdir -p /state /app/up /app/droplet /app
COPY up /app/up
COPY droplet /app/droplet

ENTRYPOINT []
CMD ["/app/up/script.py"]
ENV PYTHONUNBUFFERED="true"


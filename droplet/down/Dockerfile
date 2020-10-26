FROM hashicorp/terraform:0.13.3
COPY main.tf /app/
RUN terraform init

RUN apk update && apk add python3
COPY script.py /app/
RUN chmod +x /app/script.py
WORKDIR /app
ENV PYTHONUNBUFFERED="true"
ENTRYPOINT []
CMD ["/app/script.py"]

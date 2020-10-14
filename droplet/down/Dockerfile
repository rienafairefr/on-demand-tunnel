FROM hashicorp/terraform:0.13.3
RUN apk update && apk add python3
COPY script.py /app/
RUN chmod +x /app/script.py
COPY main.tf /app/
WORKDIR /app
ENV PYTHONUNBUFFERED="true"
ENTRYPOINT []
CMD ["/app/script.py"]

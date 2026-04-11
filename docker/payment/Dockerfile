From python:3.9.23-alpine3.22 AS builder
WORKDIR /build
RUN apk add --no-cache python3-dev build-base linux-headers pcre-dev
COPY requirements.txt .
RUN pip3 install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.9.23-alpine3.22
WORKDIR /opt/server
RUN apk add --no-cache pcre
RUN addgroup -S roboshop && adduser -S roboshop -G roboshop
USER roboshop
COPY --from=builder /install /usr/local
COPY --chown=roboshop:roboshop *.py .
COPY --chown=roboshop:roboshop payment.ini .
CMD [ "uwsgi", "--ini", "payment.ini" ]
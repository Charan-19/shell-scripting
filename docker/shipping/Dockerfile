FROM maven AS builder
WORKDIR /opt/server
COPY pom.xml .
COPY src /opt/server/src
RUN mvn clean package

FROM eclipse-temurin:17-jre-alpine
WORKDIR /opt/server
RUN addgroup -S roboshop && adduser -S roboshop -G roboshop
COPY --from=builder /opt/server/target/shipping-*.jar /opt/server/shipping.jar
ENV CART_ENDPOINT="cart:8080" \
    DB_HOST="mysql"
USER roboshop
CMD ["java", "-jar", "shipping.jar"]
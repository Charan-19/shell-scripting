FROM eclipse-temurin:17-jre-alpine
WORKDIR /opt/server
COPY pom.xml .
COPY src opt/server/src
RUN mvn clean package -DskipTests
ENV CART_ENDPOINT="cart:8080" \
    DB_HOST="mysql"
cmd ["java", "-jar", "target/shipping-*.jar"]
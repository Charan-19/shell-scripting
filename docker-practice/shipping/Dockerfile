FROM maven
WORKDIR /opt/server
COPY pom.xml .
RUN mvn clean package
RUN target/shipping-1.0.jar /opt/server/shipping.jar
COPY src /opt/server/src
ENV CART_ENDPOINT="http://cart:8080" \
    DB_HOST="http://mysql:3306"
CMD ["java", "-jar", "shipping.jar"]
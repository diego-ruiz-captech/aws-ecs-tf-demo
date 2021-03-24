FROM openjdk:11.0.10-jdk-oraclelinux7

COPY ./target /usr/src/myapp
COPY ./target/demo*.jar /usr/src/myapp/app.jar
WORKDIR /usr/src/myapp
CMD ["java", "-jar", "app.jar"]
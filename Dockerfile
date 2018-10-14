FROM dantup/dart_pi:latest

WORKDIR /app/
COPY . .
RUN pub get
EXPOSE 8080
CMD ["bin/update.dart"]
ENTRYPOINT ["dart"]

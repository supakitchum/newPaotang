FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY . .
RUN flutter --version
RUN flutter pub get

ARG API_BASE_URL=/api/v1
ARG APP_LOCALE=th-TH
RUN flutter build web \
  --release \
  --dart-define=API_BASE_URL=${API_BASE_URL} \
  --dart-define=APP_LOCALE=${APP_LOCALE}

FROM nginx:1.27-alpine AS runtime
WORKDIR /usr/share/nginx/html

COPY --from=build /app/build/web .
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

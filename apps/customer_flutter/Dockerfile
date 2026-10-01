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

RUN apk add --no-cache jq

COPY --from=build /app/build/web .
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/40-render-runtime-config.sh /docker-entrypoint.d/40-render-runtime-config.sh
RUN mkdir -p /etc/customer \
  && cp /usr/share/nginx/html/index.html /etc/customer/index.html.template \
  && chmod +x /docker-entrypoint.d/40-render-runtime-config.sh

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

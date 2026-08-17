# Use a lightweight Linux base with bash and curl
FROM alpine:3.18

# Set working directory inside container
WORKDIR /app

# Install runtime dependencies:
# - bash: to run shell scripts
# - curl: likely needed for API calls in your script
# - jq: for JSON parsing (you mentioned it's installed)
RUN apk add --no-cache bash curl jq util-linux

# Copy your entire project into the container
COPY . .

# Make the script executable inside the container
RUN chmod +x partner-sandbox-demo.sh

# Set API key as an environment variable
# Development: pass it at runtime with -e flag
# Production: use secrets management (covered later)
ENV PARTNER_API_KEY=""

# Default entry point is the shell script
ENTRYPOINT ["./partner-sandbox-demo.sh"]
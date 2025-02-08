# Set the python version as a build-time argument
ARG PYTHON_VERSION=3.12-slim-bullseye
FROM python:${PYTHON_VERSION}

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV PATH=/opt/venv/bin:$PATH

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libjpeg-dev \
    libcairo2 \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Create and activate virtual environment
RUN python -m venv /opt/venv

# Upgrade pip and install Python dependencies
COPY requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# Copy project code
COPY ./src /code
WORKDIR /code

ARG DJANGO_SECRET_KEY
ENV DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}

#run manage.py collectstatic
RUN python manage.py vendor_pull
RUN python manage.py collectstatic --noinput

#whitenoise





# Set environment variables for Django
ARG DJANGO_SECRET_KEY
ENV DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}

ARG DJANGO_DEBUG=0
ENV DJANGO_DEBUG=${DJANGO_DEBUG}

# Create entrypoint script
RUN printf "#!/bin/bash\n" > /entrypoint.sh && \
    printf "python manage.py migrate --no-input\n" >> /entrypoint.sh && \
    printf "python manage.py vendor_pull\n" >> /entrypoint.sh && \
    printf "python manage.py collectstatic --noinput\n" >> /entrypoint.sh && \
    printf "gunicorn cfehome.wsgi:application --bind \"0.0.0.0:\${PORT:-8000}\"\n" >> /entrypoint.sh

# Make entrypoint script executable
RUN chmod +x /entrypoint.sh

# Clean up
RUN apt-get remove --purge -y gcc && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]

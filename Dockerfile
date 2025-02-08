# Define o python version como argumento de build com Python 3.12 como padrão
ARG PYTHON_VERSION=3.12-slim-bullseye
FROM python:${PYTHON_VERSION}

# Cria um ambiente virtual
RUN python -m venv /opt/venv

# Define o ambiente virtual como o local atual
ENV PATH=/opt/venv/bin:$PATH

# Atualiza o pip
RUN pip install --upgrade pip

# Define variáveis de ambiente relacionadas ao Python
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Cria o diretório do código e define como diretório de trabalho
RUN mkdir -p /code
WORKDIR /code

# Copia o arquivo de requisitos para o contêiner
COPY src/requirements.txt /code/requirements.txt

# Instala dependências do sistema
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libjpeg-dev \
    libcairo2 \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Instala os requisitos do projeto Python
RUN pip install -r /code/requirements.txt

# Define variáveis de ambiente Django
ARG DJANGO_SECRET_KEY
ENV DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}

ARG DJANGO_DEBUG=0
ENV DJANGO_DEBUG=${DJANGO_DEBUG}

ARG DATABASE_URL
ENV DATABASE_URL=${DATABASE_URL}

# Copia o código do projeto para o diretório de trabalho do contêiner
COPY src /code

# Executa comandos de gerenciamento Django
RUN python manage.py vendor_pull
RUN python manage.py collectstatic --noinput

# Cria um script de execução para o projeto Django
ARG PROJ_NAME="cfehome"
RUN printf "#!/bin/bash\n" > /code/paracord_runner.sh && \
    printf "RUN_PORT=\"\${PORT:-8000}\"\n\n" >> /code/paracord_runner.sh && \
    printf "python manage.py migrate --no-input\n" >> /code/paracord_runner.sh && \
    printf "gunicorn ${PROJ_NAME}.wsgi:application --bind \"0.0.0.0:\$RUN_PORT\"\n" >> /code/paracord_runner.sh

# Torna o script bash executável
RUN chmod +x /code/paracord_runner.sh

# Limpa o cache do apt para reduzir o tamanho da imagem
RUN apt-get remove --purge -y \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Executa o projeto Django via script de execução quando o contêiner iniciar
CMD ["/code/paracord_runner.sh"]
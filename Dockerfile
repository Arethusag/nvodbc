# Build sqlserver container
FROM mcr.microsoft.com/mssql/server:2022-latest AS sqlserver

# Change to root user
USER root

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Copy initialization scripts
COPY ./dev/msql/* /usr/src/app/

# Grant permissions for the run-initialization script to be executable
RUN chmod +x /usr/src/app/run-initialization.sh

# Set the environment variables for the SQL Server image
ENV ACCEPT_EULA=Y
ENV MSSQL_SA_PASSWORD="mv!2CrC@3mv!T&"

# Expose port 1433 for access from other container
EXPOSE 1433

# Expose 12475 
EXPOSE 12475

# Run Microsoft SQL Server and initialization script concurrently
CMD /bin/bash ./entrypoint.sh

# Main Ubuntu container
FROM ubuntu:latest AS neovim

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    gcc \
    make \
    gettext \
    pkg-config \
    unzip \
    libtool \
    libtool-bin \
    autoconf \
    automake \
    libluajit-5.1-dev \
    libunibilium-dev \
    libmsgpack-dev \
    libtermkey-dev \
    libvterm-dev \
    libjemalloc-dev \
    lua5.1 \
    lua5.4 \
    liblua5.1-dev \
    liblua5.4-dev 

# Install unixODBC and the SQL Server ODBC driver
RUN apt-get install -y unixodbc unixodbc-dev curl
RUN curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc
RUN curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | tee /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update
RUN ACCEPT_EULA=Y apt-get install -y mssql-tools18
 
# Move ./dev/unix/odbc.ini to /etc/odbc.ini
COPY ./dev/unix/odbc.ini /etc/odbc.ini

# Install LuaRocks and lua dependencies
RUN apt-get install -y luarocks

# Install luasocket using LuaRocks
RUN luarocks install luasocket --lua-version=5.1

# Install luasql-odbc using LuaRocks
RUN luarocks install luasql-odbc --lua-version=5.1 CFLAGS="-DUNIXODBC -fPIC"

# Install Copas using LuaRocks
RUN luarocks install copas --lua-version=5.1

# Clone Plenary and make the modules available to Lua
RUN git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git
RUN mv plenary.nvim/lua/* /usr/local/share/lua/5.1/

# Clone and build Neovim
RUN git clone --depth 1 https://github.com/neovim/neovim.git \
    && cd neovim \
    && make \
    && make install

# Set up Neovim configuration directory
RUN mkdir -p /root/.config/nvim

# # Copy plugin code to the container
# COPY ./lua /root/.config/nvim/lua

# Create Neovim init.lua
RUN echo 'local nvodbc = require("nvodbc") \n\
nvodbc.setup({ \n\
    connections = { \n\
        test_connection = { \n\
            dsn = "sqlserver", \n\
            uname = "sa", \n\
            pwd = "mv!2CrC@3mv!T&" \n\
        } \n\
    } \n\
})' >> /root/.config/nvim/init.lua

# Set the entry point to launch Neovim
# ENTRYPOINT ["nvim"]

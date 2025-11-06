CC = gcc
CFLAGS = -I./src/libutils -fPIC
LDFLAGS = -L./lib -lutils

all: server_good server_bad client

# Build the shared library
lib/libutils.so: src/libutils/log.c
	mkdir -p lib
	$(CC) $(CFLAGS) -shared -o $@ $^

# Build the good server
server_good: src/server/server.c src/server/child.c src/server/signal.c lib/libutils.so
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

# Build the bad server
server_bad: src/server/server.c src/server/child.c src/server/signal.c lib/libutils.so
	$(CC) $(CFLAGS) -DNO_ROBUST -o $@ $^ $(LDFLAGS)

# Build the client
client: src/client/client.c lib/libutils.so
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f server_good server_bad client lib/libutils.so

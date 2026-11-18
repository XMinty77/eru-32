#include "eru.h"

int main() {
    puts("calculating primes :>");

    int max = 10;
    int primes[max];
    int n = 0;
    for (int x = 2; x < 10000; x++) {
        if (n == max) break;

        char is_prime = 1;
        for (int k = 0; k < n; k++) {
            if (x % primes[k] == 0) {
                is_prime = 0;
                break;
            }
        }

        if (is_prime) {
            primes[n++] = x;
            print_dec(x);
            putchar('\n');
        }
    }

    return 0;
}
int getsockopt(
    int sockfd,         // [IN] deskryptor gniazda
    int level,          // [IN] poziom protokołu
    int optname,        // [IN] nazwa opcji
    void *optval,       // [OUT] bufor na wynik
    socklen_t *optlen   // [IN/OUT] rozmiar bufora
);

int setsockopt(
    int sockfd,         // [IN] deskryptor gniazda
    int level,          // [IN] poziom protokołu
    int optname,        // [IN] nazwa opcji
    const void *optval, // [IN] nowa wartość
    socklen_t optlen    // [IN] rozmiar wartości
);

// Obie zwracają:
// 0  - sukces
// -1 - błąd (errno ustawione)
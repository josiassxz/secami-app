package br.gov.goias.secami.auth;

import br.gov.goias.secami.config.SecamiProperties;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.UUID;

/**
 * Helper de teste (não é um {@code @Test}, o nome não termina em "Test" de propósito
 * pra não ser coletado pelo Surefire) que fabrica JWTs "artesanais" — expirados, com
 * assinatura inválida — usando o MESMO segredo/issuer configurados na aplicação (via
 * {@link SecamiProperties}). {@link JwtService} só sabe gerar tokens válidos e
 * não-expirados, então não dá pra exercitar os caminhos de erro do
 * {@code JwtAuthFilter}/{@code AuthService.refresh} (token expirado, assinatura
 * inválida) só com ele.
 */
public final class JwtTestSupport {

    private final SecretKey key;
    private final String issuer;

    public JwtTestSupport(SecamiProperties props) {
        this.key = Keys.hmacShaKeyFor(props.getJwt().getSecret().getBytes(StandardCharsets.UTF_8));
        this.issuer = props.getJwt().getIssuer();
    }

    /** Access token com assinatura/issuer válidos, mas já expirado. */
    public String expiredAccessToken(UUID userId, List<String> roles) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(userId.toString())
                .issuer(issuer)
                .claim("type", JwtService.TYPE_ACCESS)
                .claim("roles", roles)
                .issuedAt(Date.from(now.minus(Duration.ofHours(2))))
                .expiration(Date.from(now.minus(Duration.ofHours(1))))
                .signWith(key)
                .compact();
    }

    /** Refresh token com assinatura/issuer válidos, mas já expirado. */
    public String expiredRefreshToken(UUID userId) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(userId.toString())
                .issuer(issuer)
                .claim("type", JwtService.TYPE_REFRESH)
                .issuedAt(Date.from(now.minus(Duration.ofDays(10))))
                .expiration(Date.from(now.minus(Duration.ofDays(3))))
                .signWith(key)
                .compact();
    }

    /** Token com claims válidas mas assinado com uma chave diferente (adulterado). */
    public String tokenComAssinaturaInvalida(UUID userId) {
        SecretKey outraChave = Keys.hmacShaKeyFor(
                "outra-chave-completamente-diferente-do-segredo-real-0123456789".getBytes(StandardCharsets.UTF_8));
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(userId.toString())
                .issuer(issuer)
                .claim("type", JwtService.TYPE_ACCESS)
                .claim("roles", List.of("admin"))
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(Duration.ofMinutes(15))))
                .signWith(outraChave)
                .compact();
    }
}

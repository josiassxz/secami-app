package br.gov.goias.secami.auth;

import br.gov.goias.secami.config.SecamiProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.UUID;

/** Emissão e validação de JWT (access + refresh). SPEC §9.2 / §12.2. */
@Service
public class JwtService {

    public static final String TYPE_ACCESS = "access";
    public static final String TYPE_REFRESH = "refresh";

    private final SecretKey key;
    private final SecamiProperties.Jwt cfg;

    public JwtService(SecamiProperties props) {
        this.cfg = props.getJwt();
        this.key = Keys.hmacShaKeyFor(cfg.getSecret().getBytes(StandardCharsets.UTF_8));
    }

    public String generateAccessToken(UUID userId, List<String> roles) {
        Instant now = Instant.now();
        Instant exp = now.plus(Duration.ofMinutes(cfg.getAccessTokenMinutes()));
        return Jwts.builder()
                .subject(userId.toString())
                .issuer(cfg.getIssuer())
                .claim("type", TYPE_ACCESS)
                .claim("roles", roles)
                .issuedAt(Date.from(now))
                .expiration(Date.from(exp))
                .signWith(key)
                .compact();
    }

    public String generateRefreshToken(UUID userId) {
        Instant now = Instant.now();
        Instant exp = now.plus(Duration.ofDays(cfg.getRefreshTokenDays()));
        return Jwts.builder()
                .subject(userId.toString())
                .issuer(cfg.getIssuer())
                .claim("type", TYPE_REFRESH)
                .issuedAt(Date.from(now))
                .expiration(Date.from(exp))
                .signWith(key)
                .compact();
    }

    public long accessTokenSeconds() {
        return Duration.ofMinutes(cfg.getAccessTokenMinutes()).toSeconds();
    }

    /** Valida assinatura/expiração e devolve os claims. Lança JwtException se inválido. */
    public Jws<Claims> parse(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .requireIssuer(cfg.getIssuer())
                .build()
                .parseSignedClaims(token);
    }
}

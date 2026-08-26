package br.gov.goias.secami.auth.web;

import br.gov.goias.secami.auth.AuthService;
import br.gov.goias.secami.auth.CurrentUser;
import br.gov.goias.secami.auth.web.dto.LoginRequest;
import br.gov.goias.secami.auth.web.dto.MeResponse;
import br.gov.goias.secami.auth.web.dto.RefreshRequest;
import br.gov.goias.secami.auth.web.dto.TokenResponse;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
public class AuthController {

    private final AuthService authService;
    private final CurrentUser currentUser;

    public AuthController(AuthService authService, CurrentUser currentUser) {
        this.authService = authService;
        this.currentUser = currentUser;
    }

    @PostMapping("/auth/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }

    @PostMapping("/auth/refresh")
    public TokenResponse refresh(@Valid @RequestBody RefreshRequest req) {
        return authService.refresh(req.refreshToken());
    }

    @PostMapping("/auth/logout")
    public void logout() {
        // Stateless: o cliente descarta os tokens. (Revogação/blacklist fica p/ E12.)
    }

    @GetMapping("/me")
    public MeResponse me() {
        return MeResponse.from(currentUser.require());
    }
}

package br.gov.goias.secami.identity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.UuidGenerator;

import java.time.OffsetDateTime;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

/** Identidade unificada (servidores AD e, em dev, usuários locais). SPEC §8.1. */
@Entity
@Table(name = "app_user")
@Getter
@Setter
@NoArgsConstructor
public class AppUser {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @Column(name = "ldap_guid", unique = true)
    private UUID ldapGuid;

    @Column(name = "sam_account_name", unique = true)
    private String samAccountName;

    private String email;

    @Column(nullable = false)
    private String nome;

    @Column(name = "tipo_identidade", nullable = false)
    private String tipoIdentidade = "ad";

    @Column(nullable = false)
    private boolean ativo = true;

    @Column(name = "password_hash")
    private String passwordHash;

    @Column(name = "legacy_id", unique = true)
    private String legacyId;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "user_role", joinColumns = @JoinColumn(name = "user_id"))
    @Column(name = "role")
    private Set<String> roles = new HashSet<>();

    @Generated
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Generated(event = {org.hibernate.generator.EventType.INSERT, org.hibernate.generator.EventType.UPDATE})
    @Column(name = "updated_at", insertable = false, updatable = false)
    private OffsetDateTime updatedAt;
}

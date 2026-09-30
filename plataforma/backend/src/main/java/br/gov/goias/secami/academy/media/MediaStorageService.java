package br.gov.goias.secami.academy.media;

import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import br.gov.goias.secami.config.SecamiProperties;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;

/**
 * Guarda arquivos enviados (atestado médico, foto de aluno) em disco local
 * (diretório configurável via secami.storage.base-path). Sem bucket externo
 * no MVP — mesma decisão já tomada pro app mobile (assets locais).
 */
@Service
public class MediaStorageService {

    private final MediaRepository repo;
    private final Path basePath;
    private final long maxFileSizeBytes;

    public MediaStorageService(MediaRepository repo, SecamiProperties props) {
        this.repo = repo;
        this.basePath = Path.of(props.getStorage().getBasePath()).toAbsolutePath().normalize();
        this.maxFileSizeBytes = props.getStorage().getMaxFileSizeMb() * 1024L * 1024L;
        try {
            Files.createDirectories(basePath);
        } catch (IOException e) {
            throw new UncheckedIOException("Não foi possível criar o diretório de uploads: " + basePath, e);
        }
    }

    /** Salva o arquivo em disco e cria o registro {@link Media} correspondente. */
    public Media save(MultipartFile file, String tipo) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Arquivo não enviado.");
        }
        if (file.getSize() > maxFileSizeBytes) {
            throw new BusinessException("Arquivo excede o tamanho máximo de "
                    + (maxFileSizeBytes / (1024 * 1024)) + "MB.");
        }
        String original = file.getOriginalFilename();
        String ext = (original != null && original.contains("."))
                ? original.substring(original.lastIndexOf('.'))
                : "";
        String storageKey = tipo + "/" + UUID.randomUUID() + ext;
        Path dest = basePath.resolve(storageKey).normalize();
        if (!dest.startsWith(basePath)) {
            throw new BusinessException("Nome de arquivo inválido.");
        }
        try {
            Files.createDirectories(dest.getParent());
            file.transferTo(dest);
        } catch (IOException e) {
            throw new UncheckedIOException("Falha ao salvar arquivo enviado.", e);
        }
        Media media = new Media();
        media.setTipo(tipo);
        media.setStorageKey(storageKey);
        media.setContentType(file.getContentType());
        return repo.save(media);
    }

    /** Salva bytes já em memória (ex.: baixados de uma URL do legado) — mesma
     *  lógica de {@link #save}, mas sem depender de um MultipartFile. */
    public Media saveBytes(byte[] bytes, String contentType, String originalFilename, String tipo) {
        if (bytes == null || bytes.length == 0) {
            throw new BusinessException("Arquivo vazio.");
        }
        if (bytes.length > maxFileSizeBytes) {
            throw new BusinessException("Arquivo excede o tamanho máximo de "
                    + (maxFileSizeBytes / (1024 * 1024)) + "MB.");
        }
        String ext = (originalFilename != null && originalFilename.contains("."))
                ? originalFilename.substring(originalFilename.lastIndexOf('.'))
                : "";
        String storageKey = tipo + "/" + UUID.randomUUID() + ext;
        Path dest = basePath.resolve(storageKey).normalize();
        if (!dest.startsWith(basePath)) {
            throw new BusinessException("Nome de arquivo inválido.");
        }
        try {
            Files.createDirectories(dest.getParent());
            Files.write(dest, bytes);
        } catch (IOException e) {
            throw new UncheckedIOException("Falha ao salvar arquivo.", e);
        }
        Media media = new Media();
        media.setTipo(tipo);
        media.setStorageKey(storageKey);
        media.setContentType(contentType);
        return repo.save(media);
    }

    /** Carrega o arquivo do disco pra download/visualização (admin). */
    public LoadedFile load(UUID mediaId) {
        Media media = repo.findById(mediaId)
                .orElseThrow(() -> new NotFoundException("Arquivo não encontrado."));
        Path path = basePath.resolve(media.getStorageKey()).normalize();
        if (!path.startsWith(basePath) || !Files.exists(path)) {
            throw new NotFoundException("Arquivo não encontrado no armazenamento.");
        }
        try {
            Resource resource = new UrlResource(path.toUri());
            return new LoadedFile(resource, media.getContentType(), path.getFileName().toString());
        } catch (MalformedURLException e) {
            throw new NotFoundException("Arquivo não encontrado.");
        }
    }

    public record LoadedFile(Resource resource, String contentType, String fileName) {}
}

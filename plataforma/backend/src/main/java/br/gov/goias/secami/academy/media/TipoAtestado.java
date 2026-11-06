package br.gov.goias.secami.academy.media;

import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;

/**
 * Tipo real do arquivo de atestado, lido do conteúdo (assinatura dos primeiros
 * bytes), não do que o navegador declarou: no celular a pessoa consegue mandar
 * foto da galeria/câmera e o app declarava tudo como PDF, então o admin não
 * abria. Aceita PDF e foto (JPG/PNG).
 */
public enum TipoAtestado {
    PDF("application/pdf", ".pdf"),
    JPEG("image/jpeg", ".jpg"),
    PNG("image/png", ".png");

    public final String contentType;
    public final String extensao;

    TipoAtestado(String contentType, String extensao) {
        this.contentType = contentType;
        this.extensao = extensao;
    }

    /** @throws BusinessException se não for PDF nem foto. */
    public static TipoAtestado de(MultipartFile arquivo) {
        byte[] b = new byte[8];
        int n;
        try (InputStream in = arquivo.getInputStream()) {
            n = in.readNBytes(b, 0, b.length);
        } catch (IOException e) {
            throw new BusinessException("Não foi possível ler o arquivo do atestado.");
        }
        if (n >= 4 && b[0] == '%' && b[1] == 'P' && b[2] == 'D' && b[3] == 'F') return PDF;
        if (n >= 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF) return JPEG;
        if (n >= 8 && (b[0] & 0xFF) == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') return PNG;
        throw new BusinessException("O atestado precisa ser um PDF ou uma foto (JPG ou PNG).");
    }
}

package com.photoalbum;

import com.photoalbum.model.Photo;
import com.photoalbum.repository.PhotoRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class PhotoRepositoryPostgreSqlCompatibilityTest {

    @Autowired
    private PhotoRepository photoRepository;

    @Test
    void persistsBinaryDataAndPreservesOrderingNavigationAndPagination() {
        Photo first = savePhoto("first.jpg", new byte[]{0, 1, 2}, 1);
        Photo second = savePhoto("second.jpg", new byte[]{3, 4, 5}, 2);
        Photo third = savePhoto("third.jpg", new byte[]{6, 7, 8}, 3);
        Photo fourth = savePhoto("fourth.jpg", new byte[]{9, 10, 11}, 4);

        assertThat(photoRepository.findById(first.getId()).orElseThrow().getPhotoData())
                .containsExactly(0, 1, 2);
        assertThat(photoRepository.findAllOrderByUploadedAtDesc())
                .extracting(Photo::getId)
                .containsExactly(fourth.getId(), third.getId(), second.getId(), first.getId());
        assertThat(photoRepository.findPhotosUploadedBefore(fourth.getUploadedAt()))
                .extracting(Photo::getId)
                .containsExactly(third.getId(), second.getId(), first.getId());
        assertThat(photoRepository.findPhotosUploadedAfter(second.getUploadedAt()))
                .extracting(Photo::getId)
                .containsExactly(third.getId(), fourth.getId());
        assertThat(photoRepository.findPhotosByUploadMonth("2024", "05"))
                .hasSize(4);
        assertThat(photoRepository.findPhotosWithPagination(2, 3))
                .extracting(Photo::getId)
                .containsExactly(third.getId(), second.getId());
        assertThat(photoRepository.findPhotosWithPagination(3, 2)).isEmpty();
    }

    private Photo savePhoto(String fileName, byte[] data, int day) {
        Photo photo = new Photo(
                fileName,
                data,
                fileName,
                "/uploads/" + fileName,
                (long) data.length,
                "image/jpeg");
        photo.setUploadedAt(LocalDateTime.of(2024, 5, day, 12, 0));
        return photoRepository.saveAndFlush(photo);
    }
}

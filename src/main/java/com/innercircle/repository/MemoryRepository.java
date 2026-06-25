package com.innercircle.repository;

import com.innercircle.model.Memory;
import com.innercircle.model.User;
import com.innercircle.model.Persona;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface MemoryRepository extends JpaRepository<Memory, UUID> {
    List<Memory> findByUserAndPersonaOrderByImportanceDesc(User user, Persona persona);
    List<Memory> findByUserOrderByImportanceDesc(User user);
}
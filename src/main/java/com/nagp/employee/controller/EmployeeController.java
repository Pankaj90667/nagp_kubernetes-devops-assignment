package com.nagp.employee.controller;

import com.nagp.employee.model.Employee;
import com.nagp.employee.repository.EmployeeRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class EmployeeController {
    
    @Autowired
    private EmployeeRepository employeeRepository;
    
    @GetMapping("/employees")
    public ResponseEntity<Map<String, Object>> getAllEmployees() {
        List<Employee> employees = employeeRepository.findAll();
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "success");
        response.put("message", "Employees fetched successfully from database");
        response.put("count", employees.size());
        response.put("data", employees);
        response.put("podName", System.getenv("HOSTNAME"));
        
        return ResponseEntity.ok(response);
    }
    
    @GetMapping("/employees/{id}")
    public ResponseEntity<Employee> getEmployeeById(@PathVariable Long id) {
        return employeeRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
    
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "Employee Service");
        response.put("podName", System.getenv("HOSTNAME"));
        return ResponseEntity.ok(response);
    }
}

--  CAFETERÍA "Latti Coffee House & Deli" 
DROP DATABASE cafeteria;
CREATE DATABASE IF NOT EXISTS cafeteria;
USE cafeteria;
 
--  ENTIDADES PRINCIPALES 
-- 1. PROVEEDOR
CREATE TABLE Supplier (
    supplier_id INT NOT NULL AUTO_INCREMENT,
    company_name VARCHAR(100) NOT NULL,
    contact VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100),
    address VARCHAR(200),
    PRIMARY KEY (supplier_id)
);

-- 2. INSUMO
CREATE TABLE Supply (
    supply_id INT AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    unit VARCHAR(30) NOT NULL,
    current_stock DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    minimum_stock DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    supplier_id INT,
    PRIMARY KEY (supply_id),
    CONSTRAINT fk_supply_supplier
        FOREIGN KEY (supplier_id) REFERENCES Supplier(supplier_id)
);
 
-- 3. PRODUCTO
CREATE TABLE Product (
    product_id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    price DECIMAL(8,2) NOT NULL,
    category VARCHAR(50) NOT NULL,
    available TINYINT(1) NOT NULL DEFAULT 1,
    supply_id INT,
    PRIMARY KEY (product_id),
    CONSTRAINT fk_product_supply
        FOREIGN KEY (supply_id) REFERENCES Supply(supply_id)
);
 
-- 4. EMPLEADO
CREATE TABLE Employee (
    employee_id INT NOT NULL AUTO_INCREMENT,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    position VARCHAR(50) NOT NULL,
    salary DECIMAL(10,2) NOT NULL,
    hire_date DATE NOT NULL,
    PRIMARY KEY (employee_id)
);
 
-- 5. TURNO
CREATE TABLE Shift (
    shift_id INT NOT NULL AUTO_INCREMENT,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    description VARCHAR(50),
    employee_id INT NOT NULL,
    PRIMARY KEY (shift_id),
    CONSTRAINT fk_shift_employee
        FOREIGN KEY (employee_id) REFERENCES Employee(employee_id)
);
 
-- 6. MESA
CREATE TABLE TableCafe (
    table_id INT NOT NULL AUTO_INCREMENT,
    table_number INT NOT NULL UNIQUE,
    capacity INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'available',
    location VARCHAR(50),
    PRIMARY KEY (table_id)
);
 
-- 7. CLIENTE
CREATE TABLE Customer (
    customer_id INT NOT NULL AUTO_INCREMENT,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    register_date DATE NOT NULL,
    PRIMARY KEY (customer_id)
);
 
-- 8. RESERVACION
CREATE TABLE Reservation (
    reservation_id INT NOT NULL AUTO_INCREMENT,
    date_time DATETIME NOT NULL,
    num_guests INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    customer_id INT NOT NULL,
    table_id INT NOT NULL,
    PRIMARY KEY (reservation_id),
    CONSTRAINT fk_reservation_customer
        FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    CONSTRAINT fk_reservation_table
        FOREIGN KEY (table_id) REFERENCES TableCafe(table_id)
);
 
-- 9. PEDIDO
CREATE TABLE Orders (
    order_id INT NOT NULL AUTO_INCREMENT,
    date_time DATETIME,
    total DECIMAL(10,2),
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    customer_id INT,
    employee_id INT NOT NULL,
    table_id INT,
    product_id INT,
    PRIMARY KEY (order_id),
    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    CONSTRAINT fk_order_employee
        FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    CONSTRAINT fk_order_table
        FOREIGN KEY (table_id) REFERENCES TableCafe(table_id),
    CONSTRAINT fk_order_product
        FOREIGN KEY (product_id) REFERENCES Product(product_id)
);
 
-- 10. PAGO
CREATE TABLE Payment (
    payment_id INT NOT NULL AUTO_INCREMENT,
    payment_method VARCHAR(30) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    date_time DATETIME,
    reference VARCHAR(100),
    order_id INT NOT NULL,
    PRIMARY KEY (payment_id),
    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id) REFERENCES Orders(order_id)
);
 
--  TABLA DE AUDITORÍA
CREATE TABLE Audit (
    audit_id INT NOT NULL AUTO_INCREMENT,
    affected_table VARCHAR(60) NOT NULL,
    operation ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    record_id INT NOT NULL,
    old_data TEXT,
    new_data TEXT,
    db_user VARCHAR(100) NOT NULL,
    date_time DATETIME,
    PRIMARY KEY (audit_id)
);

-- INSERTS
INSERT INTO Supplier (company_name, contact, phone, email, address) VALUES
('Café Origen S.A.', 'Roberto Méndez', '55-1234-5678', 'contacto@cafeorigen.mx', 'Av. Industrial 101, CDMX'),
('Lácteos del Valle', 'Patricia Ruiz', '55-2345-6789', 'ventas@lacteosvalle.mx', 'Carretera Toluca km 14, EdoMex'),
('Pan Artesanal del Norte', 'Carlos Ibáñez', '81-3456-7890', 'pedidos@panarte.mx', 'Calle Trigo 22, Monterrey'),
('Frutas Selectas MX', 'Lucía Flores', '33-4567-8901', 'lucia@frutaselectasmx.com', 'Mercado Abastos L-55, Guadalajara'),
('Azúcar & Cía.','Ernesto Vega', '55-5678-9012', 'evega@azucarycia.com', 'Blvd. Azucarero 8, Veracruz'),
('Distribuidora Grano Fino', 'Sandra Ortiz', '55-6789-0123', 'sortiz@granofino.mx', 'Calle Cosecha 77, Querétaro'),
('Especias del Mundo', 'Hugo Landa',  '55-7890-1234', 'hlanda@especiasmundo.com', 'Col. Centro 200, CDMX'),
('Envases y Empaques Pro', 'Valeria Salas', '55-8901-2345', 'vsalas@empaques.mx', 'Parque Industrial Sur, Puebla'),
('Chocolate Fino MX', 'Beatriz Torres', '55-9012-3456', 'btorres@chocolatefino.mx', 'Av. Cacao 33, Tabasco'),
('Cereales & Semillas SA', 'Marcos Herrera', '33-0123-4567', 'mherrera@cerealesysemill.mx', 'Zona Industrial, Jalisco'),
('Miel Pura de Abeja', 'Daniela Guerrero', '744-123-4567', 'dguerrero@mielpura.mx', 'Rancho Las Flores, Guerrero'),
('Aguas y Bebidas SA', 'Raúl Castillo', '55-1122-3344', 'rcastillo@aguasybebidas.mx', 'Av. Fuentes 55, CDMX'),
('Verduras Orgánicas MX', 'Teresa Jiménez', '55-2233-4455', 'tjimenez@verdurasmx.com', 'Km 5 Carretera Xochimilco'),
('Harinas El Molino', 'Javier Peña', '55-3344-5566', 'javier@harinasmolino.mx', 'Calle Molienda 9, Tlaxcala'),
('Aceites Premium', 'Natalia Ramos', '55-4455-6677', 'nramos@aceitespremium.com', 'Polígono Industrial A, Hidalgo'),
('Refrescos y Más', 'Omar Delgado', '55-5566-7788', 'odelgado@refrescosymas.mx', 'Av. Bebidas 200, CDMX'),
('Embutidos La Sierra', 'Carmen López', '81-6677-8899', 'clopez@embutidoslasierra.mx', 'Carretera Monterrey 12, NL'),
('Quesos Artesanales MX', 'Felipe Navarro', '33-7788-9900', 'fnavarro@quesosartmx.com', 'Rancho El Queso, Oaxaca'),
('Té y Hierbas del Sur', 'Adriana Cruz', '951-889-0011', 'acruz@tehierbas.mx', 'Mercado Benito Juárez, Oaxaca'),
('Congelados Express', 'Rodrigo Morales', '55-9900-1122', 'rmorales@congeladosexp.mx', 'Fracc. Frío 77, Estado de México');

INSERT INTO Supply (name, unit, current_stock, minimum_stock, supplier_id) VALUES
('Café molido espresso', 'kg', 45.00, 10.00,  1),
('Leche entera', 'litros', 120.00, 20.00, 2),
('Pan baguette', 'piezas', 80.00,  15.00, 3),
('Fresas frescas', 'kg', 18.00, 5.00, 4),
('Azúcar estándar', 'kg', 60.00, 10.00, 5),
('Café en grano blend', 'kg', 30.00, 8.00, 6),
('Canela molida', 'kg', 5.00, 1.00, 7),
('Vasos desechables 16 oz', 'piezas', 500.00, 100.00, 8),
('Chocolate oscuro 70%', 'kg', 12.00, 3.00, 9),
('Avena integral', 'kg', 25.00, 5.00, 10),
('Miel de abeja', 'litros', 8.00, 2.00, 11),
('Agua mineral 1L', 'botellas', 200.00, 50.00, 12),
('Espinaca baby', 'kg', 10.00, 3.00, 13),
('Harina de trigo', 'kg', 50.00, 10.00, 14),
('Aceite de oliva extra', 'litros', 15.00, 3.00, 15),
('Refresco de cola 600ml', 'botellas',150.00, 30.00, 16),
('Jamón serrano', 'kg', 8.00, 2.00, 17),
('Queso manchego', 'kg', 12.00, 3.00, 18),
('Té verde', 'g', 800.00, 200.00, 19),
('Helado de vainilla', 'litros', 10.00,   2.00, 20);
 
INSERT INTO Product (name, description, price, category, available, supply_id) VALUES
('Espresso doble', 'Doble shot de café espresso', 42.00, 'Bebida caliente', 1, 1),
('Cappuccino clásico', 'Espresso con leche vaporizada y espuma', 58.00, 'Bebida caliente', 1, 2),
('Sándwich de jamón', 'Pan baguette, jamón serrano y queso', 89.00, 'Alimento', 1, 3),
('Smoothie de fresa', 'Fresas frescas con leche y miel', 75.00, 'Bebida fría', 1, 4),
('Café con azúcar morena', 'Americano con azúcar morena al gusto', 45.00, 'Bebida caliente', 1, 5),
('Cold Brew', 'Café en infusión fría 12 h', 70.00, 'Bebida fría', 1, 6),
('Latte de canela', 'Latte con syrup de canela y leche vaporizada',65.00, 'Bebida caliente', 1, 7),
('Vaso térmico Latti', 'Vaso reutilizable de la marca', 150.00,'Mercancía', 1, 8),
('Chocolate caliente', 'Chocolate oscuro 70% con leche', 60.00, 'Bebida caliente', 1, 9),
('Bowl de avena', 'Avena integral con frutas y miel', 85.00, 'Alimento', 1, 10),
('Granola con miel', 'Granola artesanal bañada en miel de abeja', 72.00, 'Alimento', 1, 11),
('Agua mineral', 'Agua mineral natural 1L', 30.00, 'Bebida fría', 1, 12),
('Wrap de espinaca', 'Wrap integral relleno de espinaca y queso', 95.00, 'Alimento', 1, 13),
('Croissant', 'Croissant de mantequilla horneado al momento', 55.00,'Alimento', 1, 14),
('Bruschetta', 'Pan tostado con aceite de oliva y tomate', 78.00, 'Alimento', 1, 15),
('Refresco 600ml', 'Refresco de cola en botella', 35.00, 'Bebida fría', 1, 16),
('Tabla de embutidos', 'Selección de jamón serrano y queso manchego', 180.00,'Alimento', 1, 17),
('Plato de quesos', 'Queso manchego con crackers', 120.00,'Alimento', 1, 18),
('Té verde', 'Té verde en hoja suelta con agua caliente', 42.00, 'Bebida caliente', 1, 19),
('Helado artesanal', 'Copa de helado de vainilla con topping', 68.00, 'Postre', 1, 20);

INSERT INTO Employee (first_name, last_name, position, salary, hire_date) VALUES
('Ana', 'García Reyes', 'Barista', 9500.00, '2021-03-15'),
('Luis', 'Martínez Peña', 'Mesero', 8200.00, '2022-01-10'),
('Sofía', 'López Ríos', 'Cajera', 8800.00, '2020-07-20'),
('Diego', 'Hernández Cruz', 'Chef', 13000.00, '2019-11-05'),
('María', 'Jiménez Solano', 'Barista', 9500.00, '2023-02-14'),
('Carlos', 'Ramírez Tello', 'Mesero', 8200.00, '2022-08-01'),
('Valeria', 'Torres Mendoza', 'Supervisora', 12500.00, '2018-06-30'),
('Andrés', 'Flores Lima', 'Mesero', 8200.00, '2023-05-22'),
('Patricia', 'Vega Soto', 'Barista', 9500.00, '2021-09-17'),
('Emilio', 'Romero Aguilar', 'Lavaplatos', 7500.00, '2022-04-03'),
('Gabriela', 'Morales Ureña', 'Mesera', 8200.00, '2020-12-11'),
('Rubén', 'Díaz Carbajal', 'Cocinero auxiliar', 9000.00, '2021-07-25'),
('Claudia', 'Reyes Fuentes', 'Hostess', 8500.00, '2022-03-08'),
('Héctor', 'Cruz Ballesteros','Mesero', 8200.00, '2023-09-01'),
('Inés', 'Guerrero Paz', 'Barista', 9500.00, '2020-02-28'),
('Tomás', 'Peña Villanueva', 'Cocinero', 11000.00, '2019-04-16'),
('Natalia', 'Salinas Mora', 'Cajera', 8800.00, '2023-11-03'),
('Rodrigo', 'Mendoza Bravo', 'Gerente', 18000.00, '2017-08-21'),
('Laura', 'Castro Ibáñez', 'Mesera',  8200.00, '2024-01-15'),
('Javier', 'Ortega Landa', 'Barista', 9500.00, '2024-03-10');
 
INSERT INTO Shift (start_time, end_time, description, employee_id) VALUES
('07:00:00', '15:00:00', 'Matutino A', 1),
('07:00:00', '15:00:00', 'Matutino A', 2),
('07:00:00', '15:00:00', 'Matutino A', 3),
('07:00:00', '15:00:00', 'Matutino A', 4),
('08:00:00', '16:00:00', 'Matutino B', 5),
('08:00:00', '16:00:00', 'Matutino B', 6),
('08:00:00', '16:00:00', 'Matutino B', 7),
('12:00:00', '20:00:00', 'Vespertino A', 8),
('12:00:00', '20:00:00', 'Vespertino A', 9),
('12:00:00', '20:00:00', 'Vespertino A', 10),
('13:00:00', '21:00:00', 'Vespertino B', 11),
('13:00:00', '21:00:00', 'Vespertino B', 12),
('13:00:00', '21:00:00', 'Vespertino B', 13),
('15:00:00', '23:00:00', 'Nocturno A', 14),
('15:00:00', '23:00:00', 'Nocturno A', 15),
('15:00:00', '23:00:00', 'Nocturno A', 16),
('06:00:00', '14:00:00', 'Madrugada', 17),
('09:00:00', '17:00:00', 'Oficina/Admin', 18),
('10:00:00', '18:00:00', 'Partido 1', 19),
('14:00:00', '22:00:00', 'Partido 2', 20);

INSERT INTO TableCafe (table_number, capacity, status, location) VALUES
(1, 2, 'available', 'Terraza'),
(2, 2, 'available', 'Terraza'),
(3, 4, 'occupied', 'Terraza'),
(4, 4, 'available', 'Interior'),
(5, 4, 'available', 'Interior'),
(6, 6, 'occupied', 'Interior'),
(7, 6, 'reserved', 'Interior'),
(8, 2, 'available', 'Barra'),
(9, 2, 'available', 'Barra'),
(10, 2, 'occupied', 'Barra'),
(11, 4, 'available', 'Jardín'),
(12, 4, 'available', 'Jardín'),
(13, 6, 'reserved', 'Jardín'),
(14, 8, 'available', 'Salón privado'),
(15, 8, 'available', 'Salón privado'),
(16, 4, 'occupied', 'Ventanal'),
(17, 4, 'available', 'Ventanal'),
(18, 2, 'available', 'Entrada'),
(19, 2, 'reserved', 'Entrada'),
(20, 10, 'available', 'Salón privado');
 
INSERT INTO Customer (full_name, email, phone, register_date) VALUES
('Mariana Solis Vega', 'mariana.solis@gmail.com', '55-1111-2222', '2023-01-10'),
('Jorge Quintero Ríos', 'jquintero@hotmail.com', '55-2222-3333', '2023-02-15'),
('Fernanda Castillo Mora', 'fcastillo@outlook.com', '55-3333-4444', '2023-03-05'),
('Alejandro Paredes Cruz', 'aparedes@gmail.com', '55-4444-5555', '2023-03-22'),
('Camila Herrera Soto', 'camila.herrera@gmail.com', '55-5555-6666', '2023-04-01'),
('Ricardo Domínguez Peña', 'rdominguez@yahoo.com', '55-6666-7777', '2023-04-18'),
('Daniela Fuentes López', 'dfuentes@gmail.com', '55-7777-8888', '2023-05-09'),
('Sebastián Torres Ruiz', 'storres@hotmail.com', '55-8888-9999', '2023-05-30'),
('Lucía Vargas Jiménez', 'lvargas@gmail.com', '55-9999-0000', '2023-06-14'),
('Emilio Reyes Blanco', 'ereyes@outlook.com', '55-0000-1111', '2023-07-01'),
('Valeria Medina Torres', 'vmedina@gmail.com', '55-1234-9876', '2023-07-19'),
('Andrés Salinas Mora', 'asalinas@gmail.com', '55-2345-8765', '2023-08-03'),
('Isabel Guerrero Paz', 'iguerrero@hotmail.com', '55-3456-7654', '2023-08-21'),
('Francisco Ortega Lima', 'fortega@gmail.com', '55-4567-6543', '2023-09-10'),
('Renata Flores Ureña', 'rflores@yahoo.com', '55-5678-5432', '2023-09-28'),
('Mauricio Aguilar Díaz', 'maguilar@gmail.com', '55-6789-4321', '2023-10-15'),
('Patricia Ibáñez Salas', 'pibanez@outlook.com', '55-7890-3210', '2023-11-02'),
('Tomás Bravo Navarro', 'tbravo@gmail.com', '55-8901-2109', '2023-11-20'),
('Sara Mendoza Castro', 'smendoza@hotmail.com', '55-9012-1098', '2024-01-07'),
('Gabriel Ramos León', 'gramos@gmail.com', '55-0123-0987', '2024-02-14');
 
INSERT INTO Reservation (date_time, num_guests, status, customer_id, table_id) VALUES
('2024-04-01 12:00:00', 2, 'confirmed', 1, 1),
('2024-04-02 13:30:00', 4, 'confirmed', 2, 5),
('2024-04-03 19:00:00', 3, 'pending', 3, 7),
('2024-04-04 14:00:00', 2, 'confirmed', 4, 8),
('2024-04-05 11:00:00', 6, 'confirmed', 5, 6),
('2024-04-06 20:00:00', 4, 'cancelled', 6, 4),
('2024-04-07 18:30:00', 2, 'confirmed', 7, 2),
('2024-04-08 09:00:00', 4, 'pending', 8, 11),
('2024-04-09 15:00:00', 5, 'confirmed', 9, 13),
('2024-04-10 17:30:00', 2, 'confirmed', 10, 9),
('2024-04-11 12:30:00', 8, 'confirmed', 11, 14),
('2024-04-12 13:00:00', 4, 'pending', 12, 5),
('2024-04-13 19:30:00', 6, 'cancelled', 13, 6),
('2024-04-14 10:00:00', 2, 'confirmed', 14, 18),
('2024-04-15 16:00:00', 4, 'confirmed', 15, 17),
('2024-04-16 14:30:00', 10, 'pending', 16, 20),
('2024-04-17 11:30:00', 3, 'confirmed', 17, 3),
('2024-04-18 20:30:00', 2, 'confirmed', 18, 19),
('2024-04-19 13:00:00', 4, 'confirmed', 19, 12),
('2024-04-20 18:00:00', 6, 'confirmed', 20, 15);
 
INSERT INTO Orders (date_time, total, status, customer_id, employee_id, table_id, product_id) VALUES
('2024-04-01 12:15:00', 100.00, 'closed', 1, 2, 1, 1),
('2024-04-01 13:00:00', 147.00, 'closed', 2, 6, 5, 2),
('2024-04-02 09:30:00', 85.00, 'closed', 3, 1, 8, 4),
('2024-04-02 14:20:00', 180.00, 'closed', 4, 8, 11, 17),
('2024-04-03 10:00:00', 42.00, 'closed', 5, 2, 4, 1),
('2024-04-03 16:45:00', 213.00, 'closed', 6, 11, 6, 3),
('2024-04-04 11:30:00', 72.00, 'closed', 7, 6, 10, 11),
('2024-04-04 18:00:00', 120.00, 'closed', 8, 14, 16, 18),
('2024-04-05 08:45:00', 58.00, 'closed', 9, 1, 9, 2),
('2024-04-05 13:15:00', 260.00, 'closed', 10, 8, 11, 17),
('2024-04-06 12:00:00', 75.00, 'closed', 11, 2, 3, 4),
('2024-04-06 19:30:00', 95.00, 'paid', 12, 11, 16, 13),
('2024-04-07 10:45:00', 168.00, 'paid', 13, 6, 5, 7),
('2024-04-07 14:00:00', 85.00, 'paid', 14, 2, 18, 10),
('2024-04-08 09:15:00', 60.00, 'paid', 15, 1, 9, 9),
('2024-04-08 17:00:00', 150.00, 'open', 16, 14, 20, 8),
('2024-04-09 11:00:00', 68.00, 'open', 17, 8, 17, 20),
('2024-04-09 13:30:00', 180.00, 'open', 18, 6, 6, 17),
('2024-04-10 15:00:00', 42.00, 'open', 19, 2, 4, 19),
('2024-04-10 18:45:00', 120.00, 'open', 20, 11, 15, 18),
('2024-04-11 09:00:00', 58.00, 'closed', 1, 3, 1, 2),
('2024-04-11 10:00:00', 85.00, 'closed', 2, 4, 4, 3),
('2024-04-11 11:00:00', 42.00, 'closed', 3, 5, 8, 1),
('2024-04-11 12:00:00', 95.00, 'closed', 4, 7, 11, 13),
('2024-04-11 13:00:00', 60.00, 'closed', 5, 9, 5, 9),
('2024-04-11 14:00:00', 75.00, 'closed', 6, 10, 9, 4),
('2024-04-11 15:00:00', 120.00, 'closed', 7, 12, 16, 18),
('2024-04-11 16:00:00', 68.00, 'closed', 8, 13, 17, 20),
('2024-04-11 17:00:00', 45.00, 'closed', 9, 15, 2, 5),
('2024-04-11 18:00:00', 180.00, 'closed', 10, 16, 14, 17),
('2024-04-12 09:00:00', 72.00, 'closed', 11, 17, 12, 11),
('2024-04-12 10:00:00', 55.00, 'closed', 12, 18, 3, 14),
('2024-04-12 11:00:00', 42.00, 'closed', 13, 19, 8, 19),
('2024-04-12 12:00:00', 89.00, 'closed', 14, 20, 10, 3),
('2024-04-12 13:00:00', 65.00, 'closed', 15, 3, 6, 7),
('2024-04-12 14:00:00', 58.00, 'closed', 16, 4, 1, 2),
('2024-04-12 15:00:00', 78.00, 'closed', 17, 5, 15, 15),
('2024-04-12 16:00:00', 42.00, 'closed', 18, 7, 4, 1),
('2024-04-12 17:00:00', 60.00, 'closed', 19, 9, 18, 9),
('2024-04-12 18:00:00', 95.00, 'closed', 20, 10, 7, 13),
('2024-04-11 09:00:00', 58.00, 'closed', 1, 3, 1, 2),
('2024-04-11 10:00:00', 85.00, 'closed', 2, 4, 4, 3),
('2024-04-11 11:00:00', 42.00, 'closed', 3, 5, 8, 1),
('2024-04-11 12:00:00', 95.00, 'closed', 4, 7, 11, 13),
('2024-04-11 13:00:00', 60.00, 'closed', 5, 9, 5, 9),
('2024-04-11 14:00:00', 75.00, 'closed', 6, 10, 9, 4),
('2024-04-11 15:00:00', 120.00, 'closed', 7, 12, 16, 18),
('2024-04-11 16:00:00', 68.00, 'closed', 8, 13, 17, 20),
('2024-04-11 17:00:00', 45.00, 'closed', 9, 15,  2, 5),
('2024-04-11 18:00:00', 180.00, 'closed',10, 16, 14, 17),
('2024-04-12 09:00:00', 72.00, 'closed', 11, 17, 12, 11),
('2024-04-12 10:00:00', 55.00, 'closed', 12, 18,  3, 14),
('2024-04-12 11:00:00', 42.00, 'closed', 13, 19,  8, 19),
('2024-04-12 12:00:00', 89.00, 'closed', 14, 20, 10, 3),
('2024-04-12 13:00:00', 65.00, 'closed', 15, 3,  6, 7),
('2024-04-12 14:00:00', 58.00, 'closed', 16, 4,  1, 2),
('2024-04-12 15:00:00', 78.00, 'closed', 17, 5, 15, 15),
('2024-04-12 16:00:00', 42.00, 'closed', 18, 7,  4, 1),
('2024-04-12 17:00:00', 60.00, 'closed', 19, 9, 18, 9),
('2024-04-12 18:00:00', 95.00, 'closed', 20, 10, 7, 13);
 
INSERT INTO Payment (payment_method, amount, date_time, reference, order_id) VALUES
('Tarjeta débito', 100.00, '2024-04-01 12:45:00', 'TXN-001-2024',  1),
('Efectivo', 147.00, '2024-04-01 13:30:00', 'EFE-002-2024',  2),
('Tarjeta crédito', 85.00, '2024-04-02 10:00:00', 'TXN-003-2024',  3),
('Transferencia', 180.00, '2024-04-02 14:50:00', 'TRF-004-2024',  4),
('Efectivo', 42.00, '2024-04-03 10:25:00', 'EFE-005-2024',  5),
('Tarjeta débito', 213.00, '2024-04-03 17:10:00', 'TXN-006-2024',  6),
('Tarjeta crédito', 72.00, '2024-04-04 12:00:00', 'TXN-007-2024',  7),
('Efectivo', 120.00, '2024-04-04 18:25:00', 'EFE-008-2024',  8),
('QR / CoDi', 58.00, '2024-04-05 09:05:00', 'COD-009-2024',  9),
('Tarjeta débito', 260.00, '2024-04-05 13:40:00', 'TXN-010-2024', 10),
('Efectivo', 75.00, '2024-04-06 12:30:00', 'EFE-011-2024', 11),
('Tarjeta crédito', 95.00, '2024-04-06 20:00:00', 'TXN-012-2024', 12),
('Transferencia', 168.00, '2024-04-07 11:10:00', 'TRF-013-2024', 13),
('Efectivo', 85.00, '2024-04-07 14:25:00', 'EFE-014-2024', 14),
('QR / CoDi', 60.00, '2024-04-08 09:40:00', 'COD-015-2024', 15),
('Tarjeta débito', 150.00, '2024-04-08 17:30:00', 'TXN-016-2024', 16),
('Tarjeta crédito', 68.00, '2024-04-09 11:25:00', 'TXN-017-2024', 17),
('Efectivo', 180.00, '2024-04-09 14:00:00', 'EFE-018-2024', 18),
('QR / CoDi', 42.00, '2024-04-10 15:20:00', 'COD-019-2024', 19),
('Transferencia', 120.00, '2024-04-10 19:10:00', 'TRF-020-2024', 20),
('Efectivo', 58.00, '2024-04-11 09:20:00', 'EFE-021-2024', 21),
('Tarjeta débito', 85.00, '2024-04-11 10:20:00', 'TXN-022-2024', 22),
('QR / CoDi', 42.00, '2024-04-11 11:20:00', 'COD-023-2024', 23),
('Tarjeta crédito', 95.00, '2024-04-11 12:20:00', 'TXN-024-2024', 24),
('Efectivo', 60.00, '2024-04-11 13:20:00', 'EFE-025-2024', 25),
('Transferencia', 75.00, '2024-04-11 14:20:00', 'TRF-026-2024', 26),
('Tarjeta débito', 120.00, '2024-04-11 15:20:00', 'TXN-027-2024', 27),
('Efectivo', 68.00, '2024-04-11 16:20:00', 'EFE-028-2024', 28),
('QR / CoDi', 45.00, '2024-04-11 17:20:00', 'COD-029-2024', 29),
('Tarjeta crédito',  180.00, '2024-04-11 18:20:00', 'TXN-030-2024', 30),
('Efectivo', 72.00, '2024-04-12 09:20:00', 'EFE-031-2024', 31),
('Tarjeta débito', 55.00, '2024-04-12 10:20:00', 'TXN-032-2024', 32),
('Transferencia', 42.00, '2024-04-12 11:20:00', 'TRF-033-2024', 33),
('Efectivo', 89.00, '2024-04-12 12:20:00', 'EFE-034-2024', 34),
('QR / CoDi', 65.00, '2024-04-12 13:20:00', 'COD-035-2024', 35),
('Tarjeta crédito', 58.00, '2024-04-12 14:20:00', 'TXN-036-2024', 36),
('Efectivo', 78.00, '2024-04-12 15:20:00', 'EFE-037-2024', 37),
('Tarjeta débito', 42.00, '2024-04-12 16:20:00', 'TXN-038-2024', 38),
('Transferencia', 60.00, '2024-04-12 17:20:00', 'TRF-039-2024', 39),
('Efectivo', 95.00, '2024-04-12 18:20:00', 'EFE-040-2024', 40),
('Efectivo', 58.00, '2024-04-11 09:20:00', 'EFE-021-2024', 21),
('Tarjeta débito', 85.00, '2024-04-11 10:20:00', 'TXN-022-2024', 22),
('QR / CoDi', 42.00, '2024-04-11 11:20:00', 'COD-023-2024', 23),
('Tarjeta crédito', 95.00, '2024-04-11 12:20:00', 'TXN-024-2024', 24),
('Efectivo', 60.00, '2024-04-11 13:20:00', 'EFE-025-2024', 25),
('Transferencia', 75.00, '2024-04-11 14:20:00', 'TRF-026-2024', 26),
('Tarjeta débito', 120.00, '2024-04-11 15:20:00', 'TXN-027-2024', 27),
('Efectivo', 68.00, '2024-04-11 16:20:00', 'EFE-028-2024', 28),
('QR / CoDi', 45.00, '2024-04-11 17:20:00', 'COD-029-2024', 29),
('Tarjeta crédito', 180.00, '2024-04-11 18:20:00', 'TXN-030-2024', 30),
('Efectivo', 72.00, '2024-04-12 09:20:00', 'EFE-031-2024', 31),
('Tarjeta débito', 55.00, '2024-04-12 10:20:00', 'TXN-032-2024', 32),
('Transferencia', 42.00, '2024-04-12 11:20:00', 'TRF-033-2024', 33),
('Efectivo', 89.00, '2024-04-12 12:20:00', 'EFE-034-2024', 34),
('QR / CoDi', 65.00, '2024-04-12 13:20:00', 'COD-035-2024', 35),
('Tarjeta crédito', 58.00, '2024-04-12 14:20:00', 'TXN-036-2024', 36),
('Efectivo', 78.00, '2024-04-12 15:20:00', 'EFE-037-2024', 37),
('Tarjeta débito', 42.00, '2024-04-12 16:20:00', 'TXN-038-2024', 38),
('Transferencia', 60.00, '2024-04-12 17:20:00', 'TRF-039-2024', 39),
('Efectivo', 95.00, '2024-04-12 18:20:00', 'EFE-040-2024', 40);


SELECT * FROM Supplier;
SELECT * FROM Supply;
SELECT * FROM Product;
SELECT * FROM Employee;
SELECT * FROM Shift;
SELECT * FROM TableCafe;
SELECT * FROM Customer;
SELECT * FROM Reservation;
SELECT * FROM Orders;
SELECT * FROM Payment;


-- VIEW 1: Resumen de ventas por empleado
CREATE OR REPLACE VIEW vw_ventas_empleado AS
SELECT
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS empleado,
    e.position  AS puesto,
    COUNT(o.order_id) AS total_pedidos,
    SUM(o.total) AS ingresos_generados,
    AVG(o.total) AS ticket_promedio
FROM Employee e
LEFT JOIN Orders o ON e.employee_id = o.employee_id
GROUP BY e.employee_id, e.first_name, e.last_name, e.position;

-- VIEW 2: Productos más vendidos
CREATE OR REPLACE VIEW vw_productos_populares AS
SELECT
    p.product_id,
    p.name AS producto,
    p.category AS categoria,
    p.price AS precio,
    COUNT(o.order_id) AS veces_pedido,
    SUM(o.total) AS ingresos_totales
FROM Product p
LEFT JOIN Orders o ON p.product_id = o.product_id
GROUP BY p.product_id, p.name, p.category, p.price
ORDER BY veces_pedido DESC;

-- VIEW 3: Estado actual de mesas
CREATE OR REPLACE VIEW vw_estado_mesas AS
SELECT
    t.table_id,
    t.table_number AS numero_mesa,
    t.capacity AS capacidad,
    t.location AS ubicacion,
    t.status AS estado,
    r.date_time AS proxima_reservacion,
    c.full_name AS cliente_reserva
FROM TableCafe t
LEFT JOIN Reservation r ON t.table_id = r.table_id
    AND r.status IN ('confirmed','pending')
    AND r.date_time >= NOW()
LEFT JOIN Customer c ON r.customer_id = c.customer_id;

-- VIEW 4: Insumos con stock bajo
CREATE OR REPLACE VIEW vw_stock_critico AS
SELECT
    su.supply_id,
    su.name AS insumo,
    su.unit AS unidad,
    su.current_stock AS stock_actual,
    su.minimum_stock AS stock_minimo,
    (su.current_stock - su.minimum_stock) AS diferencia,
    sp.company_name  AS proveedor,
    sp.phone AS telefono_proveedor
FROM Supply su
JOIN Supplier sp ON su.supplier_id = sp.supplier_id
WHERE su.current_stock <= su.minimum_stock * 1.2
ORDER BY diferencia ASC;

-- VIEW 5: Ingresos diarios con método de pago
CREATE OR REPLACE VIEW vw_ingresos_diarios AS
SELECT
    DATE(p.date_time) AS fecha,
    p.payment_method AS metodo_pago,
    COUNT(p.payment_id) AS num_transacciones,
    SUM(p.amount) AS total_recaudado
FROM Payment p
GROUP BY DATE(p.date_time), p.payment_method
ORDER BY fecha DESC;

-- VIEW 6: Clientes frecuentes con gasto total
CREATE OR REPLACE VIEW vw_clientes_frecuentes AS
SELECT
    c.customer_id,
    c.full_name AS cliente,
    c.email,
    COUNT(o.order_id) AS total_visitas,
    SUM(o.total) AS gasto_total,
    MAX(o.date_time) AS ultima_visita
FROM Customer c
LEFT JOIN Orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.full_name, c.email
ORDER BY gasto_total DESC;

SELECT * FROM vw_ventas_empleado;
SELECT * FROM vw_productos_populares;
SELECT * FROM vw_estado_mesas;
SELECT * FROM vw_stock_critico;
SELECT * FROM vw_ingresos_diarios;
SELECT * FROM vw_clientes_frecuentes;

-- simulacion de transaccion exitosa
START TRANSACTION;
 
    INSERT INTO Orders (date_time, total, status, customer_id, employee_id, table_id, product_id)
    VALUES (NOW(), 58.00, 'open', 1, 1, 4, 2);
 
    INSERT INTO Payment (payment_method, amount, date_time, reference, order_id)
    VALUES ('cash', 58.00, NOW(), 'TXN-ACID-001', LAST_INSERT_ID());
 
COMMIT;
 
-- simulación de una transacción cancelada
START TRANSACTION;
  
    INSERT INTO Orders (date_time, total, status, customer_id, employee_id, table_id, product_id)
    VALUES (NOW(), 95.00, 'open', 2, 3, 5, 7);
 
    INSERT INTO Payment (payment_method, amount, date_time, reference, order_id)
    VALUES ('card', 95.00, NOW(), 'TXN-ACID-002', LAST_INSERT_ID());
 
ROLLBACK;
 
 
DELIMITER $$
 
-- PRODUCT
CREATE TRIGGER trg_product_insert
AFTER INSERT ON Product
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Product', 'INSERT', NEW.product_id, NULL, NEW.name, USER(), NOW());
END$$
 
CREATE TRIGGER trg_product_update
AFTER UPDATE ON Product
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Product', 'UPDATE', NEW.product_id, OLD.name, NEW.name, USER(), NOW());
END$$
 
CREATE TRIGGER trg_product_delete
AFTER DELETE ON Product
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Product', 'DELETE', OLD.product_id, OLD.name, NULL, USER(), NOW());
END$$
 
-- EMPLOYEE
CREATE TRIGGER trg_employee_insert
AFTER INSERT ON Employee
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Employee', 'INSERT', NEW.employee_id, NULL, NEW.first_name, USER(), NOW());
END$$
 
CREATE TRIGGER trg_employee_update
AFTER UPDATE ON Employee
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Employee', 'UPDATE', NEW.employee_id, OLD.first_name, NEW.first_name, USER(), NOW());
END$$
 
CREATE TRIGGER trg_employee_delete
AFTER DELETE ON Employee
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Employee', 'DELETE', OLD.employee_id, OLD.first_name, NULL, USER(), NOW());
END$$
 
 
-- ORDERS
CREATE TRIGGER trg_orders_insert
AFTER INSERT ON Orders
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Orders', 'INSERT', NEW.order_id, NULL, NEW.status, USER(), NOW());
END$$
 
CREATE TRIGGER trg_orders_update
AFTER UPDATE ON Orders
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Orders', 'UPDATE', NEW.order_id, OLD.status, NEW.status, USER(), NOW());
END$$
 
CREATE TRIGGER trg_orders_delete
AFTER DELETE ON Orders
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Orders', 'DELETE', OLD.order_id, OLD.status, NULL, USER(), NOW());
END$$
 

-- PAYMENT
CREATE TRIGGER trg_payment_insert
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Payment', 'INSERT', NEW.payment_id, NULL, NEW.payment_method, USER(), NOW());
END$$
 
CREATE TRIGGER trg_payment_update
AFTER UPDATE ON Payment
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Payment', 'UPDATE', NEW.payment_id, OLD.payment_method, NEW.payment_method, USER(), NOW());
END$$
 
CREATE TRIGGER trg_payment_delete
AFTER DELETE ON Payment
FOR EACH ROW
BEGIN
    INSERT INTO Audit (affected_table, operation, record_id, old_data, new_data, db_user, date_time)
    VALUES ('Payment', 'DELETE', OLD.payment_id, OLD.payment_method, NULL, USER(), NOW());
END$$
 
DELIMITER ;
 
SHOW TRIGGERS FROM cafeteria;
SELECT * FROM Audit ORDER BY date_time DESC;

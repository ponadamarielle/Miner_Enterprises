import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// product model
class Product {
  final String id;
  final String name;
  final String type;
  final String description;
  final double price;
  final int stockQuantity;
  final String imageUrl;
  final double installationFee;
  final double repairFee;

  Product({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.price,
    required this.stockQuantity,
    required this.imageUrl,
    required this.installationFee,
    required this.repairFee,
  });

  factory Product.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      stockQuantity: data['stockQuantity'] ?? 0,
      imageUrl: data['imageUrl'] ?? '',
      installationFee: (data['installationFee'] ?? 0).toDouble(),
      repairFee: (data['repairFee'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'description': description,
      'price': price,
      'stockQuantity': stockQuantity,
      'imageUrl': imageUrl,
      'installationFee': installationFee,
      'repairFee': repairFee,
    };
  }
}

// card
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isInStock = product.stockQuantity > 0;
    final bool isLowStock = product.stockQuantity <= 5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.grey.shade100,
                            child: Icon(Icons.image_not_supported,
                                color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          child: Icon(Icons.image, color: Colors.grey),
                        ),
                ),
              ),

              // stock badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isInStock
                        ? Color(0xFFEAF3DE)
                        : Color(0xFFFCEBEB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isInStock ? "In stock" : "Out of stock",
                    style: TextStyle(
                      fontFamily: "Arimo",
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isInStock ? Color(0xFF3B6D11) : Color(0xFFA32D2D),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // content
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    product.type.toUpperCase(),
                    style: TextStyle(
                      fontFamily: "Arimo",
                      fontSize: 10,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),

                  SizedBox(height: 2),

                  // name
                  Text(
                    product.name,
                    style: TextStyle(
                      fontFamily: "Changa One",
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF013b7a),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 2),

                  // description
                  Text(
                    product.description,
                    style: TextStyle(
                      fontFamily: "Arimo",
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  Spacer(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "₱${product.price.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isLowStock
                            ? "⚠ ${product.stockQuantity} left"
                            : "${product.stockQuantity} left",
                        style: TextStyle(
                          fontFamily: "Arimo",
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: isLowStock ? Colors.orange : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // edit & delete buttons
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // edit button
                Expanded(
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFF013b7a)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 12, color: Colors.grey.shade700),
                          SizedBox(width: 3),
                          Text(
                            "Edit",
                            style: TextStyle(
                              fontFamily: "Changa One",
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 4),

                // delete button
                Expanded(
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFdc342c)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline,
                              size: 12, color: Color(0xFFdc342c)),
                          SizedBox(width: 3),
                          Text(
                            "Del",
                            style: TextStyle(
                              fontFamily: "Changa One",
                              fontSize: 11,
                              color: Color(0xFFdc342c),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
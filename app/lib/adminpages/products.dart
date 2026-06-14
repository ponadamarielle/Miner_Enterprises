import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:miner_enterprises/adminpages/product_card.dart';

class Products extends StatefulWidget {
  const Products({super.key});

  @override
  State<Products> createState() => _ProductsState();
}

class _ProductsState extends State<Products> {
  String selectedFilter = "All";

  List<String> filters = [
    "All",
    "Split type",
    "Window type",
    "Portable",
    'Central Air',
    'Ductless Mini-splits',
    "In stock only"
  ];

  String? selectedType;

// firebase
late final CollectionReference _productsRef;

@override
void initState() {
  super.initState();
  _productsRef = FirebaseFirestore.instance.collection('products');
}
  // cloudinary 
  static const String _cloudName = 'dnx24vcvu';
  static const String _uploadPreset = 'products_preset';

Future<Uint8List?> _pickImage() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
  );

  if (result == null || result.files.isEmpty) return null;

  return result.files.first.bytes;
}

Future<String?> _uploadImage(Uint8List imageBytes, String fileName) async {
  try {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'products'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
      ));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final json = jsonDecode(body);
      return json['secure_url'] as String?;
    } else {
      debugPrint("Cloudinary upload error: $body");
      return null;
    }
  } catch (e) {
    debugPrint("Upload error: $e");
    return null;
  }
}

  // add product
  void _addProductDialog() {
    final formKey = GlobalKey<FormState>();

    TextEditingController productNameController = TextEditingController();
    TextEditingController priceController = TextEditingController();
    TextEditingController stockController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    TextEditingController installationFeeController= TextEditingController();
    TextEditingController repairFeeController= TextEditingController();

    Uint8List? pickedImage;
    bool isUploading = false;
    String? imageError;

    selectedType = null;
    imageError = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text("Add Product", style: TextStyle(fontSize: 20, fontFamily: "Changa One")),

              content: SizedBox(
                width: 550,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: productNameController,
                              decoration: InputDecoration(
                                labelText: "Product Name",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Product name is required";
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(width: 10),

                          Expanded(
                            child: DropdownButtonFormField2<String>(
                              value: selectedType,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: "Type",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),

                              validator: (value) {
                                if (value == null) {
                                  return "Type is required";
                                }
                                return null;
                              },
                              hint: Text("Select Type", style: TextStyle(fontSize: 15, fontFamily: "Arimo")),
                              items: ["Split Type", "Window Type", "Portable", "Central Air", "Ductless Mini-splits"]
                                  .map((e) => DropdownMenuItem(
                                      value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (value) {
                              setDialogState(() {
                                selectedType = value;
                              });
                            },
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceController,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                TextInputFormatter.withFunction((oldValue, newValue) {
                                  if (newValue.text.isEmpty) return newValue;

                                  if (newValue.text.length == 1 && newValue.text == '0') {
                                    return oldValue;
                                  }

                                  return newValue;
                                }),
                              ],
                              decoration: InputDecoration(
                                labelText: "Price (₱)",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Price is required";
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(width: 10),

                          Expanded(
                            child: TextFormField(
                              controller: stockController,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                TextInputFormatter.withFunction((oldValue, newValue) {
                                  if (newValue.text.isEmpty) return newValue;

                                  if (newValue.text.length == 1 && newValue.text == '0') {
                                    return oldValue;
                                  }

                                  return newValue;
                                }),
                              ],
                              decoration: InputDecoration(
                                labelText: "Stock",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Stock is required";
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: installationFeeController,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                TextInputFormatter.withFunction((oldValue, newValue) {
                                  if (newValue.text.isEmpty) return newValue;

                                  if (newValue.text.length == 1 && newValue.text == '0') {
                                    return oldValue;
                                  }

                                  return newValue;
                                }),
                              ],
                              decoration: InputDecoration(
                                labelText: "Installation Fee (₱)",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Installation fee is required";
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(width: 10),

                          Expanded(
                            child: TextFormField(
                              controller: repairFeeController,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                TextInputFormatter.withFunction((oldValue, newValue) {
                                  if (newValue.text.isEmpty) return newValue;

                                  if (newValue.text.length == 1 && newValue.text == '0') {
                                    return oldValue;
                                  }

                                  return newValue;
                                }),
                              ],
                              decoration: InputDecoration(
                                labelText: "Repair Fee (₱)",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Repair fee is required";
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      TextFormField(
                        controller: descriptionController,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          labelText: "Description",
                          labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Description is required";
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 20),

                      SizedBox(
                        height: 176,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: pickedImage != null
                                      ? Image.memory(pickedImage!, fit: BoxFit.contain)
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.image_outlined,
                                                size: 32, color: Colors.grey.shade400),
                                            SizedBox(height: 4),
                                            Text("No image", style: TextStyle(fontFamily: "Arimo", fontSize: 11, color: Colors.grey.shade400)),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            // Upload button box
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final bytes = await _pickImage();
                                  if (bytes != null) {
                                    setDialogState(() {
                                      pickedImage = bytes;
                                      imageError = null;
                                    });
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        pickedImage != null
                                            ? Icons.change_circle_outlined
                                            : Icons.upload_outlined,
                                        size: 32,
                                        color: Colors.grey.shade500,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        pickedImage != null
                                            ? "Change Image"
                                            : "Upload Image",
                                        style: TextStyle(fontFamily: "Arimo", fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (imageError != null) ...[
                              SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(17, 0, 0, 0),
                                  child: Text(
                                    imageError!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                )
                              ),
                      ],

                      if (isUploading) ...[
                        SizedBox(height: 10),
                        Row(
                          children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text("Uploading...", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Color(0xFFdc342c))),
                ),

                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          bool isValid = formKey.currentState!.validate();

                          setDialogState(() {
                            imageError = pickedImage == null ? "Image is required" : null;
                          });

                          if (!isValid || pickedImage == null) return;

                          setDialogState(() => isUploading = true);

                          String imageUrl = '';
                          if (pickedImage != null) {
                            final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
                            final url = await _uploadImage(pickedImage!, fileName);
                            if (url == null) {
                              setDialogState(() {
                                isUploading = false;
                                imageError = "Image upload failed";
                                pickedImage = null;
                              });
                              return;
                            }
                            imageUrl = url;
                          }
                          // save
                          await _productsRef.add({
                            'name': productNameController.text.trim(),
                            'type': selectedType,
                            'description': descriptionController.text.trim(),
                            'price': double.parse(priceController.text.trim()),
                            'stockQuantity':
                                int.parse(stockController.text.trim()),
                            'installationFee': double.parse(installationFeeController.text.trim()),
                            'repairFee': double.parse(repairFeeController.text.trim()),
                            'imageUrl': imageUrl,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          nav.pop();
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, elevation: 8),
                  child: Text("SAVE", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Color(0xFF013b7a), fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // edit product
  void _editProductDialog(Product product) {
    final formKey = GlobalKey<FormState>();

    TextEditingController productNameController = TextEditingController(text: product.name);
    TextEditingController priceController = TextEditingController(text: product.price.toStringAsFixed(0));
    TextEditingController stockController = TextEditingController(text: product.stockQuantity.toString());
    TextEditingController descriptionController = TextEditingController(text: product.description);
    TextEditingController installationFeeController = TextEditingController(text: product.installationFee.toStringAsFixed(0));
    TextEditingController repairFeeController = TextEditingController(text: product.repairFee.toStringAsFixed(0));

    String dialogType = product.type;
    Uint8List? pickedImage;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text("Edit Product", style: TextStyle(fontSize: 20, fontFamily: "Changa One")),

              content: SizedBox(
                width: 550,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: productNameController,
                              decoration: InputDecoration(
                                labelText: "Product Name",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Product name is required";
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(width: 10),

                          Expanded(
                            child: DropdownButtonFormField2<String>(
                              value: dialogType,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: "Type",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),
                              items: ["Split Type", "Window Type", "Portable"]
                                  .map((e) => DropdownMenuItem(
                                      value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  dialogType = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceController,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: "Price (₱)",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Price is required";
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(width: 10),

                          Expanded(
                            child: TextFormField(
                              controller: stockController,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: "Stock",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Stock is required";
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: installationFeeController,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                TextInputFormatter.withFunction((oldValue, newValue) {
                                  if (newValue.text.isEmpty) return newValue;
                                  if (newValue.text.length == 1 && newValue.text == '0') {
                                    return oldValue;
                                  }
                                  return newValue;
                                }),
                              ],
                              decoration: InputDecoration(
                                labelText: "Installation Fee (₱)",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Installation fee is required";
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(width: 10),

                          Expanded(
                            child: TextFormField(
                              controller: repairFeeController,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                TextInputFormatter.withFunction((oldValue, newValue) {
                                  if (newValue.text.isEmpty) return newValue;
                                  if (newValue.text.length == 1 && newValue.text == '0') {
                                    return oldValue;
                                  }
                                  return newValue;
                                }),
                              ],
                              decoration: InputDecoration(
                                labelText: "Repair Fee (₱)",
                                labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Repair fee is required";
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      TextFormField(
                        controller: descriptionController,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          labelText: "Description",
                          labelStyle: TextStyle(fontSize: 15, fontFamily: "Arimo"),
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),

                      SizedBox(height: 20),

                      SizedBox(
                        height: 218,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: pickedImage != null
                                      ? Image.memory(pickedImage!, fit: BoxFit.contain)
                                      : (product.imageUrl.isNotEmpty
                                          ? Image.network(product.imageUrl, fit: BoxFit.contain)
                                          : Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.image_outlined, size: 32, color: Colors.grey.shade400),
                                                SizedBox(height: 4),
                                                Text("No image", style: TextStyle(fontSize: 11, fontFamily: "Arimo", color: Colors.grey.shade400)),
                                              ],
                                            )),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),

                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final bytes = await _pickImage();
                                  if (bytes != null) {
                                    setDialogState(() => pickedImage = bytes);
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        pickedImage != null
                                            ? Icons.change_circle_outlined
                                            : Icons.upload_outlined,
                                        size: 32,
                                        color: Colors.grey.shade500,
                                      ),
                                      SizedBox(height: 4),
                                      Text("Change Image", style: TextStyle(fontSize: 11, fontFamily: "Arimo", color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (isUploading) ...[
                        SizedBox(height: 10),
                        Row(
                          children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text("Uploading...", style: TextStyle(fontSize: 12, fontFamily: "Arimo")),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Color(0xFFdc342c))),
                ),

                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isUploading = true);

                          String imageUrl = product.imageUrl;
                          if (pickedImage != null) {
                            final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
                            final url = await _uploadImage(pickedImage!, fileName);
                            if (url == null) {
                              setDialogState(() => isUploading = false);
                              if(!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text("Image upload failed.", style: TextStyle(fontFamily: "Arimo")),
                                    backgroundColor: Colors.red),
                              );
                              return;
                            }
                            imageUrl = url;
                          }

                          // save
                          await _productsRef.doc(product.id).update({
                            'name': productNameController.text.trim(),
                            'type': dialogType,
                            'description': descriptionController.text.trim(),
                            'price': double.parse(priceController.text.trim()),
                            'stockQuantity':
                                int.parse(stockController.text.trim()),
                            'installationFee': double.parse(installationFeeController.text.trim()),
                            'repairFee': double.parse(repairFeeController.text.trim()),
                            'imageUrl': imageUrl,
                          });

                          nav.pop();
                        },

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, elevation: 8),
                  child: Text("SAVE", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Color(0xFF013b7a), fontWeight: FontWeight.w700))),
              ],
            );
          },
        );
      },
    );
  }

  // confirm delete
  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (context) {
        final nav = Navigator.of(context);
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text("Delete Product", style: TextStyle(fontSize: 15, fontFamily: "Changa One")),
          content: Text('Are you sure you want to delete "${product.name}"?', style: TextStyle(fontSize: 13, fontFamily: "Arimo")),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Color(0xFF013b7a))),
            ),

            TextButton(
              onPressed: () async {
                await _productsRef.doc(product.id).delete();
                nav.pop();
              },
              child: Text("DELETE", style: TextStyle(fontSize: 13, fontFamily: "Arimo", color: Color(0xFFdc342c), fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),

      body: Padding(
        padding: EdgeInsetsGeometry.symmetric(horizontal: 80, vertical: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 180,
                  height: 40,
                  child: TextButton(
                    onPressed: _addProductDialog,
                    style: TextButton.styleFrom(
                      backgroundColor: Color(0xFF013b7a),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 10),
                        Image.asset('assets/images/add.png',
                            height: 17, width: 17),
                        SizedBox(width: 10),
                        Text("ADD PRODUCT", style: TextStyle(fontSize: 17, fontFamily: "Changa One", color: Colors.white)),
                      ],
                    ),
                  ),
                )
              ],
            ),

            SizedBox(height: 25),

            // filter
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text("Filter:", style: TextStyle(fontSize: 18, fontFamily: "Changa One")),

                SizedBox(width: 15),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: filters.map((filter) {
                    final isSelected = selectedFilter == filter;

                    return ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          selectedFilter = filter;
                        });
                      },
                      showCheckmark: false,
                      selectedColor: Color(0xFF013b7a),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontSize: 15,
                        fontFamily: "Arimo"
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            SizedBox(height: 20),

            // product card
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _productsRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final allDocs = snapshot.data!.docs;

                  allDocs.sort((a, b) {
                    final aTime = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    final bTime = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    return bTime.compareTo(aTime);
                  });

                  final filtered = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final type =
                        (data['type'] ?? '').toString().toLowerCase();
                    final stock = data['stockQuantity'] ?? 0;

                    switch (selectedFilter) {
                      case "Split type":
                        return type == "split type";
                      case "Window type":
                        return type == "window type";
                      case "Portable":
                        return type == "portable";
                      case "Central Air":
                        return type == "central air";
                      case "Ductless Mini-splits":
                        return type == "ductless mini-split";
                      case "In stock only":
                        return stock > 0;
                      default:
                        return true;
                    }
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(child: Text("No products found.", style: TextStyle(fontSize: 15, fontFamily: "Arimo"),));
                  }

                  return GridView.builder(
                    padding: EdgeInsets.all(10),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 330,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = Product.fromDoc(filtered[index]);
                      return ProductCard(
                        product: product,
                        onEdit: () => _editProductDialog(product),
                        onDelete: () => _confirmDelete(product),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
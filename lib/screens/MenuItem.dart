import 'package:flutter/material.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/Models/CartItem.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/Models/MenuItemModel.dart';
import 'package:grad_project/screens/CartScreen.dart';
import '../services/ai_service.dart';

class MenuItem extends StatefulWidget {
  final String restaurantName;
  final MenuItemModel item;
  const MenuItem({super.key, required this.item, required this.restaurantName});
  static const String routeName = "MenuItem";

  @override
  State<MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<MenuItem> {
  late LanguageProvider lp;
  String selectedSize = 'Medium';
  int quantity = 1;
  Set<String> selectedAddOns = {};

  bool _shouldListen = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceItemScreen());
  }

  @override
  void dispose() {
    _shouldListen = false;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    lp = Provider.of<LanguageProvider>(context);
  }

  // ─────────────────────────────────────────
  // FULL ITEM SCREEN ANNOUNCEMENT
  // ─────────────────────────────────────────
  Future<void> _announceItemScreen() async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();

    // 1. Item name + description
    if (lp.isEnglish) {
      await audio.speak("Item details screen.", "en-US");
      await Future.delayed(const Duration(milliseconds: 300));
      await audio.speak(
        "You selected ${widget.item.name}. ${widget.item.description}.",
        "en-US",
      );
    } else {
      await audio.speak("شاشة تفاصيل العنصر.", "ar-SA");
      await Future.delayed(const Duration(milliseconds: 200));
      await audio.speak("اخترت", "ar-SA");
      await Future.delayed(const Duration(milliseconds: 150));
      await audio.speak(widget.item.name, "en-US");
      await Future.delayed(const Duration(milliseconds: 150));
      await audio.speak(widget.item.description, "ar-SA");
    }

    await Future.delayed(const Duration(milliseconds: 300));

    // 2. Base price
    await audio.speak(
      lp.isEnglish
          ? "Base price: ${widget.item.price.toStringAsFixed(2)} Egyptian pounds."
          : "السعر الأساسي: ${widget.item.price.toStringAsFixed(2)} جنيه مصري.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    await Future.delayed(const Duration(milliseconds: 300));

    // 3. Size options
    await audio.speak(
      lp.isEnglish
          ? "Size options: Small, standard price. Medium, standard price. Large, plus 50 Egyptian pounds."
          : "خيارات الحجم: صغير، السعر الأساسي. متوسط، السعر الأساسي. كبير، زيادة 50 جنيه مصري.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    await Future.delayed(const Duration(milliseconds: 300));

    // 4. Add-ons
    if (widget.item.availableAddOns.isNotEmpty) {
      await audio.speak(
        lp.isEnglish ? "Available add-ons:" : "الإضافات المتاحة:",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      for (var entry in widget.item.availableAddOns.entries) {
        await Future.delayed(const Duration(milliseconds: 200));
        await audio.speak(
          lp.isEnglish
              ? "${entry.key}: plus ${entry.value.toStringAsFixed(2)} Egyptian pounds."
              : "${entry.key}: زيادة ${entry.value.toStringAsFixed(2)} جنيه مصري.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));

    // 5. Current total
    await _speakCurrentTotal();

    await Future.delayed(const Duration(milliseconds: 300));

    // 6. Instructions
    await audio.speak(
      lp.isEnglish
          ? "Say small, medium, or large to choose a size. "
          "Say the name of an add-on to toggle it. "
          "Say more or less to change quantity. "
          "Say add to cart to confirm. "
          "Say go back to return to the menu."
          : "قل صغير أو متوسط أو كبير لاختيار الحجم. "
          "قل اسم الإضافة لتفعيلها أو إلغائها. "
          "قل زيادة أو تقليل لتغيير الكمية. "
          "قل أضف للسلة للتأكيد. "
          "قل ارجع للعودة للقائمة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    if (mounted) {
      _shouldListen = true;
      _startListening();
    }
  }

  // ─────────────────────────────────────────
  // SPEAK CURRENT TOTAL
  // ─────────────────────────────────────────
  Future<void> _speakCurrentTotal() async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.speak(
      lp.isEnglish
          ? "Current total: ${totalPrice.toStringAsFixed(2)} Egyptian pounds. Quantity: $quantity."
          : "الإجمالي الحالي: ${totalPrice.toStringAsFixed(2)} جنيه مصري. الكمية: $quantity.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
  }

  // ─────────────────────────────────────────
  // VOICE LISTEN LOOP
  // ─────────────────────────────────────────
  void _startListening() async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.currentLanguage,
          (words) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        debugPrint("USER SAID (MenuItem): $words");
        final response = await AIService.sendMessage(words, screen: "menu_item");


        // ── FIX: extract both command AND value from the response map ──
        final command = (response['command'] ?? "unknown").toString();
        final value   = (response['value']   ?? "").toString();
        debugPrint("AI COMMAND (MenuItem): $command | VALUE: $value");

        await _handleCommand(command, value, words);

        _isProcessing = false;

      },
      onError: (errorMsg) {
        // AudioProvider handles error_no_match automatically.
        // Only restart here for genuine errors.
        debugPrint("STT real error on screen: $errorMsg");
      },
    );
  }

  // ─────────────────────────────────────────
  // COMMAND HANDLER  (now receives value too)
  // ─────────────────────────────────────────
  Future<void> _handleCommand(String command, String value, String rawText) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    switch (command) {

    // ── NEW: handles {command: select_size, value: Small|Medium|Large} ──
      case "select_size":
        String raw = value.toLowerCase();

        final looksValid = raw.isNotEmpty &&
            !raw.contains('|') &&
            RegExp(r'(small|medium|large)').allMatches(raw).length == 1;

        if (!looksValid) raw = rawText.toLowerCase();

        String size = '';
        if (raw.contains('large')) {
          size = 'Large';
        } else if (raw.contains('medium')) {
          size = 'Medium';
        } else if (raw.contains('small')) {
          size = 'Small';
        }

        if (size.isNotEmpty) {
          if (size != selectedSize) setState(() => selectedSize = size);
          await audio.speak("$size selected.", lp.isEnglish ? "en-US" : "ar-SA");
          await _speakCurrentTotal();
        } else {
          await audio.speak(
            lp.isEnglish
                ? "Sorry, please say small, medium, or large."
                : "عذراً، قل صغير أو متوسط أو كبير.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
        break;
    // ── kept as fallback in case Rasa ever returns the old command names ──

      case "increase_quantity":
        setState(() => quantity++);
        await audio.speak(
          lp.isEnglish
              ? "Quantity increased to $quantity."
              : "الكمية زادت إلى $quantity.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await _speakCurrentTotal();
        break;

      case "decrease_quantity":
        if (quantity > 1) {
          setState(() => quantity--);
          await audio.speak(
            lp.isEnglish
                ? "Quantity decreased to $quantity."
                : "الكمية قلت إلى $quantity.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          await _speakCurrentTotal();
        } else {
          await audio.speak(
            lp.isEnglish
                ? "Minimum quantity is 1."
                : "الحد الأدنى للكمية هو 1.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
        break;

      case "add_to_cart":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish
              ? "Adding ${widget.item.name} to cart. "
              "Size: $selectedSize. "
              "Quantity: $quantity. "
              "${selectedAddOns.isNotEmpty ? 'Add-ons: ${selectedAddOns.join(', ')}.' : 'No add-ons.'} "
              "Total: ${totalPrice.toStringAsFixed(2)} Egyptian pounds."
              : "جاري إضافة ${widget.item.name} للسلة. "
              "الحجم: $selectedSize. "
              "الكمية: $quantity. "
              "${selectedAddOns.isNotEmpty ? 'الإضافات: ${selectedAddOns.join('، ')}.' : 'بدون إضافات.'} "
              "الإجمالي: ${totalPrice.toStringAsFixed(2)} جنيه مصري.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        _addToCart();
        break;

      case "go_back":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Going back to menu." : "العودة للقائمة.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );

        await audio.stop();
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.pop(context);
        break;

      case "read_commands":
        await audio.speak(
          lp.isEnglish
              ? "Commands: say small, medium, or large for size. "
              "Say more or less for quantity. "
              "Say an add-on name to toggle it. "
              "Say add to cart to confirm. "
              "Say go back to return."
              : "الأوامر: قل صغير أو متوسط أو كبير للحجم. "
              "قل زيادة أو تقليل للكمية. "
              "قل اسم إضافة لتفعيلها. "
              "قل أضف للسلة للتأكيد. "
              "قل ارجع للعودة.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

      default:
      // Check if user named an add-on
        bool foundAddon = false;
        for (var addon in widget.item.availableAddOns.keys) {
          if (rawText.toLowerCase().contains(addon.toLowerCase())) {
            foundAddon = true;
            setState(() {
              if (selectedAddOns.contains(addon)) {
                selectedAddOns.remove(addon);
              } else {
                selectedAddOns.add(addon);
              }
            });
            final isNowSelected = selectedAddOns.contains(addon);
            await audio.speak(
              lp.isEnglish
                  ? "${isNowSelected ? 'Added' : 'Removed'} $addon. "
                  "${isNowSelected ? 'Plus ${widget.item.availableAddOns[addon]!.toStringAsFixed(2)} Egyptian pounds.' : ''}"
                  : "${isNowSelected ? 'تمت إضافة' : 'تم حذف'} $addon. "
                  "${isNowSelected ? 'زيادة ${widget.item.availableAddOns[addon]!.toStringAsFixed(2)} جنيه مصري.' : ''}",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            await _speakCurrentTotal();
            break;
          }
        }
        if (!foundAddon) {
          await audio.speak(
            lp.isEnglish
                ? "Command not recognized. Say small, medium, large, more, less, add to cart, or go back."
                : "الأمر غير معروف. قل صغير أو متوسط أو كبير أو زيادة أو تقليل أو أضف للسلة أو ارجع.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
    }
  }

  void _addToCart() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(CartItem(
      id: DateTime.now().toString(),
      name: widget.item.name,
      restaurant: widget.restaurantName,
      details:
      "${lp.getText('size_${selectedSize.toLowerCase()}')} • ${selectedAddOns.join(', ')}",
      price: totalPrice / quantity,
      quantity: quantity,
      image: widget.item.image,
    ));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  double get totalPrice {
    double total = widget.item.price;
    if (selectedSize == 'Large') total += 50.0;
    for (var addon in selectedAddOns) {
      total += widget.item.availableAddOns[addon] ?? 0.0;
    }
    return total * quantity;
  }

  @override
  Widget build(BuildContext context) {
    final audio = Provider.of<AppAudioProvider>(context);
    const primaryRed = Color(0xFFEB1B33);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(widget.item.image,
                    height: 300, width: double.infinity, fit: BoxFit.cover),
                Positioned(
                  top: 40,
                  left: lp.isRTL ? null : 20,
                  right: lp.isRTL ? 20 : null,
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFF4EDE4),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () async {
                        _shouldListen = false;
                        await audio.stop();
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: lp.isRTL ? null : 20,
                  left: lp.isRTL ? 20 : null,
                  child: FloatingActionButton(
                    backgroundColor: audio.isListening ? Colors.green : primaryRed,
                    onPressed: () {
                      if (!audio.speech.isListening && !_isProcessing) {
                        _shouldListen = true;
                        _startListening();
                      }
                    },
                    child: Icon(
                        audio.isListening ? Icons.graphic_eq : Icons.mic,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.name,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.item.description,
                      style: const TextStyle(color: Colors.grey, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text("${widget.item.price.toStringAsFixed(2)} EGP",
                      style: const TextStyle(
                          fontSize: 20,
                          color: primaryRed,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 25),

                  // Voice hint bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                        color: const Color(0xFFD6E0E0),
                        borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      children: [
                        Icon(Icons.mic,
                            color:
                            audio.isListening ? Colors.green : Colors.teal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            audio.isListening && audio.lastWords.isNotEmpty
                                ? audio.lastWords
                                : (lp.isEnglish
                                ? "Say small, medium, large, add-on name, or add to cart"
                                : "قل صغير أو متوسط أو كبير أو اسم إضافة أو أضف للسلة"),
                            style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  Text(lp.getText('select_size'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['Small', 'Medium', 'Large']
                        .map((size) => _buildSizeButton(size, primaryRed))
                        .toList(),
                  ),

                  const SizedBox(height: 25),
                  Text(lp.getText('add_ons'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  ...widget.item.availableAddOns.keys
                      .map((addon) => _buildAddOnTile(
                      addon, widget.item.availableAddOns[addon]!)),

                  const SizedBox(height: 25),
                  Text(lp.getText('quantity'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildQuantitySelector(primaryRed),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomBar(primaryRed),
    );
  }

  Widget _buildSizeButton(String size, Color primaryRed) {
    bool isSelected = selectedSize == size;
    return GestureDetector(
      onTap: () async {
        setState(() => selectedSize = size);
        final audio = Provider.of<AppAudioProvider>(context, listen: false);
        await audio.speak(
          lp.isEnglish
              ? "$size size selected. ${size == 'Large' ? 'Plus 50 Egyptian pounds.' : ''}"
              : "تم اختيار الحجم ${size == 'Small' ? 'الصغير' : size == 'Medium' ? 'المتوسط' : 'الكبير'}. "
              "${size == 'Large' ? 'زيادة 50 جنيه مصري.' : ''}",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await _speakCurrentTotal();
      },
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Text(lp.getText('size_${size.toLowerCase()}'),
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold)),
            if (size == 'Large')
              Text("+50 EGP",
                  style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.grey,
                      fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOnTile(String name, double price) {
    bool isSelected = selectedAddOns.contains(name);
    return GestureDetector(
      onTap: () async {
        setState(
                () => isSelected ? selectedAddOns.remove(name) : selectedAddOns.add(name));
        final nowSelected = selectedAddOns.contains(name);
        final audio = Provider.of<AppAudioProvider>(context, listen: false);
        await audio.speak(
          lp.isEnglish
              ? "${nowSelected ? 'Added' : 'Removed'} $name. "
              "${nowSelected ? 'Plus ${price.toStringAsFixed(2)} Egyptian pounds.' : ''}"
              : "${nowSelected ? 'تمت إضافة' : 'تم حذف'} $name. "
              "${nowSelected ? 'زيادة ${price.toStringAsFixed(2)} جنيه مصري.' : ''}",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await _speakCurrentTotal();
      },
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEB1B33).withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? const Color(0xFFEB1B33) : Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected ? const Color(0xFFEB1B33) : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Text("+${price.toStringAsFixed(2)} EGP",
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(Color primaryRed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () async {
            if (quantity > 1) {
              setState(() => quantity--);
              final audio =
              Provider.of<AppAudioProvider>(context, listen: false);
              await audio.speak(
                lp.isEnglish ? "Quantity: $quantity." : "الكمية: $quantity.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
              await _speakCurrentTotal();
            }
          },
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10)),
          child: Text("$quantity",
              style: const TextStyle(fontSize: 18)),
        ),
        IconButton(
          onPressed: () async {
            setState(() => quantity++);
            final audio =
            Provider.of<AppAudioProvider>(context, listen: false);
            await audio.speak(
              lp.isEnglish ? "Quantity: $quantity." : "الكمية: $quantity.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            await _speakCurrentTotal();
          },
          icon: Icon(Icons.add_circle_outline, color: primaryRed),
        ),
      ],
    );
  }

  Widget _buildBottomBar(Color primaryRed) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
          color: Colors.white,
          border:
          Border(top: BorderSide(color: Colors.black12, width: 0.5))),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: () async {
          _shouldListen = false;
          final audio =
          Provider.of<AppAudioProvider>(context, listen: false);
          await audio.speak(
            lp.isEnglish
                ? "Adding ${widget.item.name} to cart. Total: ${totalPrice.toStringAsFixed(2)} Egyptian pounds."
                : "جاري إضافة ${widget.item.name} للسلة. الإجمالي: ${totalPrice.toStringAsFixed(2)} جنيه مصري.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          _addToCart();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                const SizedBox(width: 10),
                Text(lp.getText('add_to_cart'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            Text("${totalPrice.toStringAsFixed(2)} EGP",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
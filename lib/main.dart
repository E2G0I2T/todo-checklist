import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  initializeDateFormatting().then((_) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        primaryColor: Colors.blueGrey,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          color: Colors.black45,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueGrey,
          secondary: Colors.lightBlueAccent,
        ),
      ),
      locale: const Locale('en', 'US'),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: $error');
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    );
    _bannerAd.load();
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 30),
          if (_isBannerAdReady)
            SizedBox(
              width: _bannerAd.size.width.toDouble(),
              height: _bannerAd.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: const [TimeBasedTodoPage(), ChecklistPage()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'To-do',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist),
            label: 'CheckList',
          ),
        ],
      ),
    );
  }
}

class TimeBasedTodoPage extends StatefulWidget {
  const TimeBasedTodoPage({super.key});

  @override
  _TimeBasedTodoPageState createState() => _TimeBasedTodoPageState();
}

class _TimeBasedTodoPageState extends State<TimeBasedTodoPage> {
  List<TodoItem> todos = [];

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosData = prefs.getString('todos');
    if (todosData != null) {
      setState(() {
        todos = TodoItem.decode(todosData);
      });
    }
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('todos', TodoItem.encode(todos));
  }

  void _addTodo() async {
    final result = await showDialog<TodoItem>(
      context: context,
      builder: (context) => const AddTodoDialog(),
    );

    if (result != null) {
      setState(() {
        todos.add(result);
      });
      _saveTodos();
    }
  }

  void _editTodo(int index) async {
    final todo = todos[index];
    final result = await showDialog<TodoItem>(
      context: context,
      builder: (context) => EditTodoDialog(todoItem: todo),
    );

    if (result != null) {
      setState(() {
        todos[index] = result;
      });
      _saveTodos();
    }
  }

  void _deleteTodo(int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm deletion'),
        content: const Text('Are you sure you want to delete it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      setState(() {
        todos.removeAt(index);
      });
      _saveTodos();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final dateFormat = DateFormat('MM/dd/EEE/a/hh:mm', 'en_US');
    return dateFormat.format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: todos.length,
        itemBuilder: (context, index) {
          final todo = todos[index];
          return ListTile(
            title: Text(
              _formatDateTime(todo.time),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            subtitle: Text(
              todo.title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () => _editTodo(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTodo(index),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTodo,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TodoItem {
  String title;
  DateTime time;

  TodoItem({required this.title, required this.time});

  static Map<String, dynamic> toJson(TodoItem item) => {
        'title': item.title,
        'time': item.time.toIso8601String(),
      };

  static TodoItem fromJson(Map<String, dynamic> json) => TodoItem(
        title: json['title'],
        time: DateTime.parse(json['time']),
      );

  static String encode(List<TodoItem> todos) => json.encode(
        todos
            .map<Map<String, dynamic>>((todo) => TodoItem.toJson(todo))
            .toList(),
      );

  static List<TodoItem> decode(String todos) =>
      (json.decode(todos) as List<dynamic>)
          .map<TodoItem>((item) => TodoItem.fromJson(item))
          .toList();
}

class AddTodoDialog extends StatefulWidget {
  const AddTodoDialog({super.key});

  @override
  _AddTodoDialogState createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends State<AddTodoDialog> {
  final TextEditingController _titleController = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          selectedDate =
              DateTime(date.year, date.month, date.day, time.hour, time.minute);
          selectedTime = time;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Todo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => _pickDateTime(context),
            child: Text(selectedDate == null
                ? 'Select Date and Time'
                : DateFormat('yyyy/MM/dd/EEE/a/hh:mm', 'en_US')
                    .format(selectedDate!)),
          ),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (selectedDate != null) {
              final todo = TodoItem(
                title: _titleController.text,
                time: selectedDate!,
              );
              Navigator.of(context).pop(todo);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class EditTodoDialog extends StatefulWidget {
  final TodoItem todoItem;

  const EditTodoDialog({Key? key, required this.todoItem}) : super(key: key);

  @override
  _EditTodoDialogState createState() => _EditTodoDialogState();
}

class _EditTodoDialogState extends State<EditTodoDialog> {
  final TextEditingController _titleController = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.todoItem.title;
    selectedDate = widget.todoItem.time;
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDate ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          selectedDate =
              DateTime(date.year, date.month, date.day, time.hour, time.minute);
          selectedTime = time;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Todo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => _pickDateTime(context),
            child: Text(selectedDate == null
                ? 'Select Date and Time'
                : DateFormat('yyyy/MM/dd/EEE/a/hh:mm', 'en_US')
                    .format(selectedDate!)),
          ),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (selectedDate != null) {
              final updatedTodo = TodoItem(
                title: _titleController.text,
                time: selectedDate!,
              );
              Navigator.of(context).pop(updatedTodo);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class ChecklistItem {
  String title;
  bool isDone;

  ChecklistItem({required this.title, this.isDone = false});

  static Map<String, dynamic> toJson(ChecklistItem item) => {
        'title': item.title,
        'isDone': item.isDone,
      };

  static ChecklistItem fromJson(Map<String, dynamic> json) => ChecklistItem(
        title: json['title'],
        isDone: json['isDone'] ?? false,
      );
}

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});
  @override
  _ChecklistPageState createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  List<String> checklistNames = [];
  Map<String, List<ChecklistItem>> checklistItems = {};

  @override
  void initState() {
    super.initState();
    _loadChecklists();
  }

  Future<void> _loadChecklists() async {
    final prefs = await SharedPreferences.getInstance();
    final storedChecklists = prefs.getString('checklists');
    if (storedChecklists != null) {
      final decodedChecklists =
          json.decode(storedChecklists) as Map<String, dynamic>;
      setState(() {
        checklistNames = List<String>.from(decodedChecklists.keys);
        checklistItems = decodedChecklists.map((key, value) => MapEntry(
            key,
            List<ChecklistItem>.from(
                value.map((item) => ChecklistItem.fromJson(item)))));
      });
    }
  }

  Future<void> _saveChecklists() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedChecklists = json.encode(checklistItems.map((key, value) =>
        MapEntry(
            key, value.map((item) => ChecklistItem.toJson(item)).toList())));
    await prefs.setString('checklists', encodedChecklists);
  }

  void _addChecklist() async {
    final newChecklistName = await showDialog<String>(
        context: context,
        builder: (context) {
          final textController = TextEditingController();
          return AlertDialog(
            title: const Text('New CheckList'),
            content: TextField(
              controller: textController,
              decoration: const InputDecoration(labelText: 'CheckList Title'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (textController.text.isNotEmpty) {
                    Navigator.of(context).pop(textController.text);
                  }
                },
                child: const Text('add'),
              ),
            ],
          );
        });

    if (newChecklistName != null && newChecklistName.isNotEmpty) {
      setState(() {
        checklistNames.add(newChecklistName);
        checklistItems[newChecklistName] = [];
      });
      _saveChecklists();
    }
  }

  void _editChecklistName(String oldName) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        final textController = TextEditingController(text: oldName);
        return AlertDialog(
          title: const Text('Edit checklist name'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(labelText: 'new name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('cancel'),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  Navigator.of(context).pop(textController.text);
                }
              },
              child: const Text('save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      setState(() {
        int index = checklistNames.indexOf(oldName);
        if (index != -1) {
          checklistNames[index] = newName;
          checklistItems[newName] = checklistItems[oldName]!;
          checklistItems.remove(oldName);
        }
      });
      _saveChecklists();
    }
  }

  void _deleteChecklist(String checklistName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete checklist'),
        content: Text(
            '$checklistName Are you sure you want to delete the checklist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('delete'),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      setState(() {
        checklistNames.remove(checklistName);
        checklistItems.remove(checklistName);
      });
      _saveChecklists();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: checklistNames.length,
        itemBuilder: (context, index) {
          final checklistName = checklistNames[index];
          return ListTile(
            title: Text(checklistName),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChecklistDetailPage(
                    name: checklistName,
                    items: checklistItems[checklistName] ?? [],
                    onItemsUpdated: (updatedItems) {
                      setState(() {
                        checklistItems[checklistName] = updatedItems;
                      });
                      _saveChecklists();
                    },
                  ),
                ),
              );
            },
            trailing: Wrap(
              spacing: 12,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () => _editChecklistName(checklistName),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteChecklist(checklistName),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addChecklist,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ChecklistDetailPage extends StatefulWidget {
  final String name;
  final List<ChecklistItem> items;
  final Function(List<ChecklistItem>) onItemsUpdated;

  const ChecklistDetailPage({
    Key? key,
    required this.name,
    required this.items,
    required this.onItemsUpdated,
  }) : super(key: key);

  @override
  _ChecklistDetailPageState createState() => _ChecklistDetailPageState();
}

class _ChecklistDetailPageState extends State<ChecklistDetailPage> {
  late List<ChecklistItem> items;

  @override
  void initState() {
    super.initState();
    items = widget.items;
  }

  void _addItem() {
    final newItem = ChecklistItem(title: 'new item');
    setState(() {
      items.add(newItem);
    });
    widget.onItemsUpdated(items);
  }

  void _toggleItem(int index, bool? value) {
    setState(() {
      items[index].isDone = value ?? false;
    });
    widget.onItemsUpdated(items);
  }

  void _editItem(int index) async {
    final textController = TextEditingController(text: items[index].title);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('edit item'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(labelText: 'new title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('cancel'),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  Navigator.of(context).pop(textController.text);
                }
              },
              child: const Text('save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        items[index].title = newName;
      });
      widget.onItemsUpdated(items);
    }
  }

  void _deleteItem(int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('delete item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('delete'),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      setState(() {
        items.removeAt(index);
      });
      widget.onItemsUpdated(items);
    }
  }

  void _deleteCheckedItems() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete checked items'),
        content:
            const Text('Are you sure you want to delete all checked items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('save'),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      setState(() {
        items.removeWhere((item) => item.isDone);
      });
      widget.onItemsUpdated(items);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteCheckedItems,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            title: Text(
              item.title,
              style: TextStyle(
                decoration: item.isDone ? TextDecoration.lineThrough : null,
                color: item.isDone ? Colors.grey : null,
              ),
            ),
            leading: Checkbox(
              value: item.isDone,
              onChanged: (value) => _toggleItem(index, value),
            ),
            trailing: Wrap(
              spacing: 12,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editItem(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteItem(index),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}

part of 'pages.dart';

class DataPage extends StatefulWidget {
  const DataPage({Key? key}) : super(key: key);

  @override
  _DataPageState createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  List<User> users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final faceData = await DatabaseHelper.instance.getAllFaceData();
    setState(() {
      users = faceData.map((data) => User.fromMap(data)).toList();
    });
  }

  Future<void> _editName(User user) async {
    final TextEditingController _controller =
        TextEditingController(text: user.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Name'),
        content: TextField(
          controller: _controller,
          decoration: InputDecoration(hintText: "Enter new name"),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Save'),
            onPressed: () => Navigator.of(context).pop(_controller.text),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      // Update the name in the database
      await DatabaseHelper.instance.updateUserName(user.id, newName);
      _loadUsers(); // Reload the list
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteFaceData(user.id);
      _loadUsers(); // Reload the list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          // Add this custom back button
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.read<PageCubit>().goToMainPage(),
        ),
        title: Text('Manage Face Data'),
      ),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            title: Text(user.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _editName(user),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _deleteUser(user),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

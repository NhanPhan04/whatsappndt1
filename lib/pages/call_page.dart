import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class CallPage extends StatefulWidget {
  final String sourceUserId;

  const CallPage({Key? key, required this.sourceUserId}) : super(key: key);

  @override
  _CallPageState createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  TextEditingController searchController = TextEditingController();
  List<dynamic> callHistory = [];
  List<dynamic> filteredCallHistory = [];
  bool isLoading = true;
  String errorMessage = "";

  int currentPage = 1;
  int totalPages = 1;
  bool isFetchingMore = false;

  String? selectedCallTypeFilter; // "incoming", "outgoing", "missed"
  String? selectedDateFilter; // "today", "yesterday", "last7days"

  @override
  void initState() {
    super.initState();
    _fetchCalls();
    searchController.addListener(_filterCallsLocally);
  }

  Future<void> _fetchCalls({bool isLoadMore = false}) async {
    if (isLoadMore && currentPage >= totalPages) return;

    setState(() {
      if (isLoadMore) {
        isFetchingMore = true;
      } else {
        isLoading = true;
        errorMessage = "";
      }
    });

    try {
      final result = await AuthService.fetchCalls(
        page: isLoadMore ? currentPage + 1 : 1,
        limit: 10,
        type: selectedCallTypeFilter,
        date: selectedDateFilter,
      );

      if (result['success']) {
        setState(() {
          final newCalls = result['calls'];
          if (isLoadMore) {
            callHistory.addAll(newCalls);
          } else {
            callHistory = newCalls;
          }
          currentPage = result['currentPage'];
          totalPages = result['totalPages'];
          _filterCallsLocally(); // Áp dụng bộ lọc tìm kiếm cục bộ
        });
      } else {
        setState(() {
          errorMessage = result['message'] ?? "Không thể tải lịch sử cuộc gọi.";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Lỗi kết nối: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
        isFetchingMore = false;
      });
    }
  }

  void _filterCallsLocally() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredCallHistory = callHistory.where((call) {
        final participantName = call['caller']['_id'] == widget.sourceUserId
            ? (call['receiver']['name'] ?? call['receiver']['email'])
            : (call['caller']['name'] ?? call['caller']['email']);
        return participantName.toLowerCase().contains(query);
      }).toList();
    });
  }

  Icon _getCallStatusIcon(String status, String callType, String participantId) {
    bool isMyCall = participantId == widget.sourceUserId; // Là cuộc gọi của mình (người gọi hoặc người nhận)

    if (status == 'missed') {
      return Icon(Icons.call_missed, color: Colors.red, size: 18);
    } else if (status == 'incoming') {
      return Icon(Icons.call_received, color: Colors.green, size: 18);
    } else if (status == 'outgoing') {
      return Icon(Icons.call_made, color: Colors.green, size: 18);
    } else if (status == 'answered') {
      return Icon(Icons.call, color: Colors.green, size: 18);
    } else if (status == 'declined') {
      return Icon(Icons.call_end, color: Colors.red, size: 18);
    }
    return Icon(Icons.call, color: Colors.grey, size: 18);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Tìm kiếm cuộc gọi...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                DropdownButton<String>(
                  hint: Text("Loại cuộc gọi"),
                  value: selectedCallTypeFilter,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedCallTypeFilter = newValue;
                      currentPage = 1; // Reset trang khi thay đổi bộ lọc
                      callHistory.clear(); // Xóa dữ liệu cũ
                    });
                    _fetchCalls();
                  },
                  items: <String>['incoming', 'outgoing', 'missed', 'answered', 'declined']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value == 'incoming' ? 'Cuộc gọi đến' :
                      value == 'outgoing' ? 'Cuộc gọi đi' :
                      value == 'missed' ? 'Cuộc gọi nhỡ' :
                      value == 'answered' ? 'Đã trả lời' : 'Đã từ chối'),
                    );
                  }).toList(),
                ),
                DropdownButton<String>(
                  hint: Text("Thời gian"),
                  value: selectedDateFilter,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedDateFilter = newValue;
                      currentPage = 1;
                      callHistory.clear();
                    });
                    _fetchCalls();
                  },
                  items: <String>['today', 'yesterday', 'last7days']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value == 'today' ? 'Hôm nay' :
                      value == 'yesterday' ? 'Hôm qua' : '7 ngày qua'),
                    );
                  }).toList(),
                ),
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      selectedCallTypeFilter = null;
                      selectedDateFilter = null;
                      currentPage = 1;
                      callHistory.clear();
                    });
                    _fetchCalls();
                  },
                ),
              ],
            ),
          ),
          isLoading && callHistory.isEmpty
              ? Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(errorMessage, style: TextStyle(color: Colors.red)),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _fetchCalls,
                    child: Text("Thử lại"),
                  ),
                ],
              ),
            ),
          )
              : Expanded(
            child: ListView.builder(
              itemCount: filteredCallHistory.length + (isFetchingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == filteredCallHistory.length) {
                  if (currentPage < totalPages) {
                    _fetchCalls(isLoadMore: true);
                    return Center(child: CircularProgressIndicator());
                  } else {
                    return SizedBox.shrink();
                  }
                }
                final call = filteredCallHistory[index];
                final isCaller = call['caller']['_id'] == widget.sourceUserId;
                final participant = isCaller ? call['receiver'] : call['caller'];
                final callStatus = call['callStatus'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFF075E54),
                    backgroundImage: participant['profilePictureUrl'] != null && participant['profilePictureUrl'].isNotEmpty
                        ? NetworkImage(participant['profilePictureUrl'])
                        : null,
                    child: (participant['profilePictureUrl'] == null || participant['profilePictureUrl'].isEmpty)
                        ? Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  title: Text(participant['name'] ?? participant['email']),
                  subtitle: Row(
                    children: [
                      _getCallStatusIcon(callStatus, call['callType'], isCaller ? call['caller']['_id'] : call['receiver']['_id']),
                      SizedBox(width: 5),
                      Text(timeago.format(DateTime.parse(call['timestamp']))),
                      if (call['duration'] > 0 && callStatus != 'missed' && callStatus != 'declined')
                        Text(" (${call['duration']}s)"),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.call, color: Color(0xFF075E54)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Gọi lại ${participant['name']} sẽ được phát triển")),
                      );
                      // TODO: Thực hiện cuộc gọi lại
                    },
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Xem chi tiết cuộc gọi với ${participant['name']} sẽ được phát triển")),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Bắt đầu cuộc gọi mới sẽ được phát triển")),
          );
        },
        backgroundColor: Color(0xFF075E54),
        child: Icon(Icons.call, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

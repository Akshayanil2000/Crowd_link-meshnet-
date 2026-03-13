import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class PrivateMessageScreen extends StatefulWidget {
  final String userName;
  final String meshId;
  final String initials;

  const PrivateMessageScreen({
    Key? key,
    required this.userName,
    required this.meshId,
    required this.initials,
  }) : super(key: key);

  @override
  _PrivateMessageScreenState createState() => _PrivateMessageScreenState();
}

class _PrivateMessageScreenState extends State<PrivateMessageScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildChatArea(),
            ),
            _buildInputField(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.backgroundBlack,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceCharcoal,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceCharcoal),
            ),
            child: Center(
              child: Text(
                widget.initials,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userName,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.meshId,
                style: GoogleFonts.inter(
                  color: AppColors.primaryNeonGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {},
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: AppColors.surfaceCharcoal,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceCharcoal,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Text(
              'Encrypted Chat',
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildReceiverMessage(text: 'hi', showAvatar: true, showName: true),
        const SizedBox(height: 16),
        _buildSenderMessage(text: 'hlo'),
        const SizedBox(height: 16),
        _buildReceiverMessage(text: 'hdj', showAvatar: true, showName: true),
        const SizedBox(height: 16),
        _buildReceiverMessage(text: 'hi', showAvatar: true, showName: true),
        const SizedBox(height: 4),
        _buildReceiverMessage(text: 'hi', showAvatar: false, showName: false),
        const SizedBox(height: 4),
        _buildReceiverMessage(text: 'hi', showAvatar: false, showName: false),
      ],
    );
  }

  Widget _buildReceiverMessage({required String text, required bool showAvatar, required bool showName}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showAvatar)
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8.0),
            decoration: const BoxDecoration(
              color: AppColors.surfaceCharcoal,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.initials,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        else
          const SizedBox(width: 40), 
        
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showName)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                  child: Text(
                    widget.userName,
                    style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceCharcoal,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    bottomLeft: Radius.zero,
                  ),
                ),
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSenderMessage({required String text}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
                child: Text(
                  'me',
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: const BoxDecoration(
                  color: AppColors.primaryNeonGreen,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.zero,
                  ),
                ),
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: AppColors.backgroundBlack,
        border: Border(
          top: BorderSide(color: AppColors.surfaceCharcoal),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceCharcoal,
                borderRadius: BorderRadius.circular(24.0),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
                    onPressed: () {},
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryNeonGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNeonGreen.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black, size: 20),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

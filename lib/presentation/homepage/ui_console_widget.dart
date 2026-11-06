import 'package:bullkysms/presentation/homepage/homepage_bin.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UiConsoleWidget extends StatelessWidget {
  UiConsoleWidget({super.key});

  final HomepageCon controller = Get.put(HomepageCon());

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Live App Console",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        color: Colors.white70,
                        size: 18,
                      ),
                      tooltip: "Copy Logs",
                      onPressed: controller.copyLogs,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.white70,
                        size: 18,
                      ),
                      tooltip: "Clear Logs",
                      onPressed: controller.clearLogs,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Obx(() {
                return ListView.builder(
                  controller: controller.scrollController,
                  itemCount: controller.logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        controller.logs[index],
                        style: const TextStyle(
                          color: Colors.lightGreenAccent,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

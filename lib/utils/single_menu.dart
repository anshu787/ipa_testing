import 'package:flutter/material.dart';

class SingleMenu extends StatelessWidget {
  final IconData icon;
  final String menuName;
  final Color color;
  final VoidCallback action;

  SingleMenu({
    required this.icon,
    required this.menuName,
    required this.color,
    required this.action,
    required TextStyle style,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: action,
        child: Container(
          padding: EdgeInsets.fromLTRB(10.0, 30.0, 10.0, 30.0),
          decoration: BoxDecoration(
            border:
                Border.all(color: Colors.grey[300] ?? Colors.black, width: 0.5),
          ),
          child: Column(
            children: [
              Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18.0,
                  color: Colors.white,
                ),
              ),
              SizedBox(
                height: 10.0,
              ),
              Container(
                child: Text(
                  menuName,
                  style: TextStyle(fontSize: 12.0, color: color),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

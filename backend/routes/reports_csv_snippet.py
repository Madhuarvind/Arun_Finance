@reports_bp.route("/export-daybook-csv", methods=["GET"])
@jwt_required()
def export_daybook_csv():
    """
    Generates a CSV Daybook Report for the given date.
    Query Param: date (YYYY-MM-DD), default today.
    """
    import csv
    import io
    from flask import Response

    try:
        current_user = get_admin_user()
        if not current_user:
            return jsonify({"msg": "Admin access required"}), 403

        date_str = request.args.get("date")
        if date_str:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        else:
            target_date = datetime.utcnow().date() # UTC for server consistency

        # Fetch Data (Same logic as XML)
        collections = (
            db.session.query(Collection)
            .join(Loan, Collection.loan_id == Loan.id)
            .join(User, Collection.agent_id == User.id)
            .filter(
                func.date(Collection.created_at) == target_date,
                Collection.status == "approved"
            )
            .order_by(Collection.created_at.desc())
            .all()
        )

        # Create CSV in Memory
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Header
        writer.writerow(["Date", "Time", "Customer Name", "Agent Name", "Amount", "Mode", "Status"])

        total_amount = 0
        for c in collections:
            # Format time
            c_time = c.created_at.strftime("%H:%M:%S")
            c_customer = c.loan.customer.name
            c_agent = c.agent.name
            c_amount = c.amount_collected
            c_mode = "Cash" # Default or from metadata if available
            # If you have payment_mode in Collection model, use it. Assuming simple for now.
            
            writer.writerow([
                target_date, c_time, c_customer, c_agent, c_amount, c_mode, "Approved"
            ])
            total_amount += c_amount

        # Footer
        writer.writerow([])
        writer.writerow(["", "", "", "Total Collection", total_amount, "", ""])

        # Create Response
        output.seek(0)
        return Response(
            output.getvalue(),
            mimetype="text/csv",
            headers={"Content-Disposition": f"attachment;filename=Daybook_{target_date}.csv"}
        )

    except Exception as e:
        print(f"CSV Export Error: {e}")
        return jsonify({"msg": f"Error generating CSV: {str(e)}"}), 500

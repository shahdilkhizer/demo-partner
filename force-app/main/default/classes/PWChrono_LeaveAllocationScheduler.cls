/**
 * @description Schedulable class to run leave allocation batch annually
 * Schedule: Run on January 1st every year at 2 AM
 * Example: System.schedule('Annual Leave Allocation', '0 0 2 1 1 ?', new PWChrono_LeaveAllocationScheduler());
 */
public without sharing class PWChrono_LeaveAllocationScheduler implements Schedulable {
  public void execute(SchedulableContext sc) {
    // Execute batch with batch size of 50
    PWChrono_LeaveAllocationBatch batch = new PWChrono_LeaveAllocationBatch();
    Database.executeBatch(batch, 50);
  }
}
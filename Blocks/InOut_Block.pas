{
   Copyright (C) 2006 The devFlowcharter project.
   The initial author of this file is Michal Domagala.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
}



unit InOut_Block;

interface

uses
   Vcl.Graphics, Base_Block, Types;

type

   TInOutBlock = class(TBlock)
      protected
         FLabel,
         FLabelSegoe: string;
         constructor Create(ABranch: TBranch; const ABlockParms: TBlockParms; const AText: string; AdjustWidth: boolean); overload;
         procedure Paint; override;
         procedure PutTextControls; override;
   end;

   TInputBlock = class(TInOutBlock)
      public
         constructor Create(ABranch: TBranch; const ABlockParms: TBlockParms); overload;
         constructor Create(ABranch: TBranch); overload;
   end;

   TOutputBlock = class(TInOutBlock)
      public
         constructor Create(ABranch: TBranch; const ABlockParms: TBlockParms); overload;
         constructor Create(ABranch: TBranch); overload;
   end;

implementation

uses
   Vcl.Controls, System.Classes, WinApi.Windows, System.Types, System.UITypes, System.Math,
   Infrastructure;

const
   DEF_BLOCK_WIDTH    = 153;
   DEF_BLOCK_HEIGHT   = 64;
   BOTTOM_POINT_Y = DEF_BLOCK_HEIGHT - 30;

constructor TInOutBlock.Create(ABranch: TBranch; const ABlockParms: TBlockParms; const AText: string; AdjustWidth: boolean);
var
   w: integer;
begin

   inherited Create(ABranch, ABlockParms);

   FStatement.Anchors := [akRight, akLeft, akTop];
   FShape := shpParallel;
   FStatement.Color := GSettings.GetShapeColor(FShape);
   FStatement.Text := AText;
   PutTextControls;
   if AdjustWidth then
   begin
      w :=  TInfra.GetTextWidth(FStatement.Text, FStatement) + FStatement.Left + 20;
      if Width < w then
         Width := w;
   end;
   w := GInfra.CurrentLang.InOutCursorPos;
   FStatement.SelStart := IfThen(w <= 0, Length(FStatement.Text) + w, w - 1);
   BottomHook := Width div 2;
   BottomPoint.X := BottomHook;
   BottomPoint.Y := BOTTOM_POINT_Y;
   IPoint.X := BottomHook + 30;
   IPoint.Y := BOTTOM_POINT_Y + 10;
   TopHook.X := BottomHook;
   Constraints.MinWidth := DEF_BLOCK_WIDTH;
   Constraints.MinHeight := DEF_BLOCK_HEIGHT;
end;

constructor TInputBlock.Create(ABranch: TBranch; const ABlockParms: TBlockParms);
begin
   FLabel := i18Manager.GetString('CaptionIn');
   FLabelSegoe := GInfra.CurrentLang.LabelIn;
   inherited Create(ABranch, ABlockParms, GInfra.CurrentLang.InputFunction, false);
end;

constructor TInputBlock.Create(ABranch: TBranch);
begin
   FLabel := i18Manager.GetString('CaptionIn');
   FLabelSegoe := GInfra.CurrentLang.LabelIn;
   inherited Create(ABranch, TBlockParms.New(blInput, 0, 0, DEF_BLOCK_WIDTH, DEF_BLOCK_HEIGHT), GInfra.CurrentLang.InputFunction, true);
end;

constructor TOutputBlock.Create(ABranch: TBranch; const ABlockParms: TBlockParms);
begin
   FLabel := i18Manager.GetString('CaptionOut');
   FLabelSegoe := GInfra.CurrentLang.LabelOut;
   inherited Create(ABranch, ABlockParms, GInfra.CurrentLang.OutputFunction, false);
end;

constructor TOutputBlock.Create(ABranch: TBranch);
begin
   FLabel := i18Manager.GetString('CaptionOut');
   FLabelSegoe := GInfra.CurrentLang.LabelOut;
   inherited Create(ABranch, TBlockParms.New(blOutput, 0, 0, DEF_BLOCK_WIDTH, DEF_BLOCK_HEIGHT), GInfra.CurrentLang.OutputFunction, true);
end;

procedure TInOutBlock.Paint;
var
   R: TRect;
   w: integer;
   fontStyles: TFontStyles;
   lColor: TColor;
begin
   inherited;
   w := Canvas.TextWidth(FLabel);
   DrawArrow(BottomPoint, BottomPoint.X, Height-1);
   Canvas.Brush.Style := bsClear;
   lColor := GSettings.GetShapeColor(FShape);
   if lColor <> GSettings.DesktopColor then
      Canvas.Brush.Color := lColor;
   Canvas.Polygon([Point(20, 0),
                   Point(Width-1, 0),
                   Point(Width-21, BOTTOM_POINT_Y),
                   Point(0, BOTTOM_POINT_Y),
                   Point(20, 0)]);
   Canvas.MoveTo(w+33, 0);
   Canvas.LineTo(w+13, BOTTOM_POINT_Y);
   fontStyles := Canvas.Font.Style;
   Canvas.Font.Style := [];
   R := Rect(17, 1, w+17, BOTTOM_POINT_Y-3);
   DrawText(Canvas.Handle, PChar(FLabel), -1, R, DT_SINGLELINE or DT_VCENTER);
   Canvas.Font.Style := fontStyles;
   DrawBlockLabel(5, BOTTOM_POINT_Y, FLabelSegoe);
   DrawI;
end;

procedure TInOutBlock.PutTextControls;
begin
   var l := Canvas.TextWidth(FLabel) + 34;
   var t := (BOTTOM_POINT_Y - FStatement.Height) div 2 + 3;
   if t < 6 then
      t := 2 * t - 6;
   FStatement.SetBounds(l, t, Width-l-20, FStatement.Height);
end;

end.
